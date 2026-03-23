import os
import uuid
from functools import lru_cache
from pathlib import Path
from typing import Annotated

import boto3
import bcrypt
import firebase_admin
from fastapi import Depends, FastAPI, File, Form, Header, HTTPException, UploadFile, status
from fastapi.middleware.cors import CORSMiddleware
from firebase_admin import auth, credentials, firestore
from pydantic import BaseModel
from dotenv import load_dotenv


load_dotenv(Path(__file__).with_name('.env'))


class UploadUrlRequest(BaseModel):
    taskId: str
    fileName: str
    contentType: str | None = None


class DownloadUrlRequest(BaseModel):
    objectKey: str
    fileName: str | None = None
    contentType: str | None = None


class ChildDownloadUrlRequest(BaseModel):
    objectKey: str
    taskId: str
    assignmentId: str
    childId: str
    fileName: str | None = None
    contentType: str | None = None


class AdminSubmissionDownloadUrlRequest(BaseModel):
    submissionId: str
    fileName: str | None = None
    contentType: str | None = None


class VerifyChildPinRequest(BaseModel):
    childId: str
    pin: str


class SetChildPinRequest(BaseModel):
    childId: str
    pin: str


class ChildSubmissionAttachment(BaseModel):
    objectKey: str
    fileName: str
    contentType: str
    sizeBytes: int | None = None


class ChildSubmissionRequest(BaseModel):
    assignmentId: str
    childId: str
    taskId: str | None = None
    note: str | None = None
    attachments: list[ChildSubmissionAttachment] = []


class ChildDirectoryItem(BaseModel):
    id: str
    name: str
    avatar: str
    totalPoints: int


class DeleteObjectsRequest(BaseModel):
    attachmentKeys: list[str]


class S3Settings(BaseModel):
    bucket: str
    region: str
    access_key_id: str
    secret_access_key: str
    prefix: str = 'task_attachments'


@lru_cache(maxsize=1)
def get_s3_settings() -> S3Settings:
    bucket = os.getenv('AWS_S3_BUCKET', '').strip()
    region = os.getenv('AWS_S3_REGION', '').strip()
    access_key_id = os.getenv('AWS_ACCESS_KEY_ID', '').strip()
    secret_access_key = os.getenv('AWS_SECRET_ACCESS_KEY', '').strip()
    prefix = os.getenv('AWS_S3_PREFIX', 'task_attachments').strip('/ ')

    if not bucket or not region or not access_key_id or not secret_access_key:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=(
                'AWS S3 is not configured for attachments. Set AWS_S3_BUCKET, '
                'AWS_S3_REGION, AWS_ACCESS_KEY_ID, and AWS_SECRET_ACCESS_KEY.'
            ),
        )

    return S3Settings(
        bucket=bucket,
        region=region,
        access_key_id=access_key_id,
        secret_access_key=secret_access_key,
        prefix=prefix or 'task_attachments',
    )


@lru_cache(maxsize=1)
def get_s3_client():
    settings = get_s3_settings()
    return boto3.client(
        's3',
        region_name=settings.region,
        aws_access_key_id=settings.access_key_id,
        aws_secret_access_key=settings.secret_access_key,
    )


@lru_cache(maxsize=1)
def init_firebase_admin():
    if firebase_admin._apps:
        return firebase_admin.get_app()

    service_account_path = os.getenv('FIREBASE_SERVICE_ACCOUNT_PATH', '').strip()
    if service_account_path:
        return firebase_admin.initialize_app(
            credentials.Certificate(service_account_path),
        )

    return firebase_admin.initialize_app()


@lru_cache(maxsize=1)
def get_firestore_client():
    init_firebase_admin()
    return firestore.client()


def sanitize_file_name(file_name: str) -> str:
    return ''.join(
        character if character.isalnum() or character in '._-' else '_'
        for character in (file_name or 'attachment')
    )[:120]


def get_allowed_origins() -> list[str]:
    configured = os.getenv(
        'S3_API_ALLOWED_ORIGINS',
        '',
    )
    return [origin.strip() for origin in configured.split(',') if origin.strip()]


def get_allowed_origin_regex() -> str:
    configured = os.getenv('S3_API_ALLOWED_ORIGIN_REGEX', '').strip()
    if configured:
        return configured
    return r'^https?://(localhost|127\.0\.0\.1)(:\d+)?$'


def get_admin_attachment_prefix(uid: str) -> str:
    settings = get_s3_settings()
    return f'{settings.prefix}/{uid}/'


def get_child_submission_prefix(child_id: str, assignment_id: str) -> str:
    settings = get_s3_settings()
    return f'{settings.prefix}/child_submissions/{child_id}/{assignment_id}/'


def ensure_owned_attachment_key(uid: str, object_key: str) -> str:
    normalized_key = (object_key or '').strip()
    if not normalized_key.startswith(get_admin_attachment_prefix(uid)):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail='You can only access attachments created for your own admin account.',
        )
    return normalized_key


def build_object_key(uid: str, task_id: str, file_name: str) -> str:
    settings = get_s3_settings()
    safe_file_name = sanitize_file_name(file_name)
    return (
        f'{settings.prefix}/{uid}/{task_id}/'
        f'{uuid.uuid4().hex}_{safe_file_name}'
    )


def build_child_submission_object_key(child_id: str, assignment_id: str, file_name: str) -> str:
    safe_file_name = sanitize_file_name(file_name)
    return (
        f'{get_child_submission_prefix(child_id, assignment_id)}'
        f'{uuid.uuid4().hex}_{safe_file_name}'
    )


async def require_admin_user(
    authorization: Annotated[str | None, Header()] = None,
) -> dict:
    if not authorization or not authorization.lower().startswith('bearer '):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='A Firebase Bearer token is required.',
        )

    id_token = authorization.split(' ', 1)[1].strip()
    if not id_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='A Firebase Bearer token is required.',
        )

    init_firebase_admin()
    try:
        decoded_token = auth.verify_id_token(id_token)
    except Exception as error:  # pragma: no cover - passthrough for auth library errors
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f'Unable to verify the Firebase ID token: {error}',
        ) from error

    firestore_client = get_firestore_client()
    admin_snapshot = (
        firestore_client.collection('admins').document(decoded_token['uid']).get()
    )
    if not admin_snapshot.exists:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail='Only admin users can manage task attachments.',
        )

    return decoded_token


async def require_child_user(
    authorization: Annotated[str | None, Header()] = None,
) -> dict:
    if not authorization or not authorization.lower().startswith('bearer '):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='A Firebase Bearer token is required.',
        )

    id_token = authorization.split(' ', 1)[1].strip()
    if not id_token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='A Firebase Bearer token is required.',
        )

    init_firebase_admin()
    try:
        decoded_token = auth.verify_id_token(id_token)
    except Exception as error:  # pragma: no cover - passthrough for auth library errors
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f'Unable to verify the Firebase ID token: {error}',
        ) from error

    role = str(decoded_token.get('role', '')).strip().lower()
    claimed_child_id = str(decoded_token.get('childId', '')).strip()
    uid = str(decoded_token.get('uid', '')).strip()

    if not claimed_child_id and uid.startswith('child_'):
        claimed_child_id = uid.removeprefix('child_').strip()

    if role != 'child' or not claimed_child_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail='Only child users can access child task attachments.',
        )

    firestore_client = get_firestore_client()
    child_snapshot = firestore_client.collection('children').document(claimed_child_id).get()
    if not child_snapshot.exists:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail='The child account linked to this token does not exist.',
        )

    child_data = child_snapshot.to_dict() or {}
    if str(child_data.get('status', '')).strip().lower() != 'active':
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail='The child account is not active.',
        )

    decoded_token['childId'] = claimed_child_id
    decoded_token['childDoc'] = child_data
    return decoded_token


def require_document_string(data: dict, field_name: str) -> str:
    value = str(data.get(field_name, '')).strip()
    if not value:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f'Missing required field {field_name}.',
        )
    return value


def require_request_string(value: str | None, field_name: str) -> str:
    normalized_value = str(value or '').strip()
    if not normalized_value:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f'{field_name} is required.',
        )
    return normalized_value


def require_four_digit_pin(pin: str | None) -> str:
    normalized_pin = require_request_string(pin, 'pin')
    if not normalized_pin.isdigit() or len(normalized_pin) != 4:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail='PIN must be exactly 4 digits.',
        )
    return normalized_pin


def require_non_negative_int(value: int | None, field_name: str) -> int:
    if value is None:
        return 0
    if value < 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f'{field_name} must not be negative.',
        )
    return int(value)


def normalize_note(note: str | None) -> str:
    normalized_note = str(note or '').strip()
    if len(normalized_note) > 2000:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail='note must be 2000 characters or fewer.',
        )
    return normalized_note


def load_child_profile(*, firestore_client, child_id: str):
    child_ref = firestore_client.collection('children').document(child_id)
    child_snapshot = child_ref.get()
    if not child_snapshot.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail='Child not found.',
        )

    child_data = child_snapshot.to_dict() or {}
    return child_ref, child_data


def ensure_active_child(child_data: dict) -> None:
    if str(child_data.get('status', '')).strip().lower() != 'active':
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail='Child account is not active.',
        )


def hash_child_pin(pin: str) -> str:
    hashed_pin = bcrypt.hashpw(pin.encode('utf-8'), bcrypt.gensalt())
    return hashed_pin.decode('utf-8')


def verify_child_pin_hash(pin: str, pin_hash: str) -> bool:
    try:
        return bcrypt.checkpw(pin.encode('utf-8'), pin_hash.encode('utf-8'))
    except ValueError:
        return False


def create_child_custom_token(child_id: str) -> str:
    init_firebase_admin()
    custom_token = auth.create_custom_token(
        f'child_{child_id}',
        {'role': 'child', 'childId': child_id},
    )
    if isinstance(custom_token, bytes):
        return custom_token.decode('utf-8')
    return str(custom_token)


def infer_proof_type(content_type: str) -> str:
    normalized_content_type = str(content_type or '').strip().lower()
    if normalized_content_type.startswith('image/'):
        return 'photo'
    if normalized_content_type.startswith('video/'):
        return 'video'
    if normalized_content_type.startswith('audio/'):
        return 'audio'
    return 'file'


def ensure_submittable_assignment(assignment_data: dict) -> None:
    normalized_status = str(assignment_data.get('status', '')).strip().lower()
    if normalized_status not in {'assigned', 'rejected'}:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail='This assignment cannot be submitted in its current status.',
        )


def build_child_directory_item(*, child_id: str, child_data: dict) -> ChildDirectoryItem:
    raw_name = str(child_data.get('name', '')).strip()
    raw_avatar = str(child_data.get('avatar', '')).strip()
    total_points = child_data.get('totalPoints', 0)

    if isinstance(total_points, bool):
        total_points = 0
    elif isinstance(total_points, (int, float)):
        total_points = int(total_points)
    else:
        total_points = 0

    display_name = raw_name or 'Child'
    avatar_source = raw_avatar or display_name
    avatar = avatar_source[:1].upper() or 'C'

    return ChildDirectoryItem(
        id=child_id,
        name=display_name,
        avatar=avatar,
        totalPoints=total_points,
    )


def load_child_assignment(
    *,
    firestore_client,
    assignment_id: str,
    child_id: str,
    task_id: str | None = None,
) -> dict:
    assignment_snapshot = firestore_client.collection('assignments').document(assignment_id).get()
    if not assignment_snapshot.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail='Assignment not found.',
        )

    assignment_data = assignment_snapshot.to_dict() or {}
    assignment_child_id = require_document_string(assignment_data, 'childId')
    assignment_task_id = require_document_string(assignment_data, 'taskId')

    if assignment_child_id != child_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail='This assignment does not belong to the authenticated child.',
        )

    if task_id is not None and assignment_task_id != task_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail='This assignment does not reference the requested task.',
        )

    return assignment_data


def load_task_attachment(
    *,
    firestore_client,
    task_id: str,
    object_key: str,
) -> dict:
    task_snapshot = firestore_client.collection('tasks').document(task_id).get()
    if not task_snapshot.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail='Task not found.',
        )

    task_data = task_snapshot.to_dict() or {}
    attachments = task_data.get('attachments')
    if not isinstance(attachments, list):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail='Task does not contain any attachments.',
        )

    normalized_object_key = object_key.strip()
    for attachment in attachments:
        if not isinstance(attachment, dict):
            continue
        if str(attachment.get('objectKey', '')).strip() == normalized_object_key:
            return attachment

    raise HTTPException(
        status_code=status.HTTP_404_NOT_FOUND,
        detail='Attachment not found on the requested task.',
    )


def load_submission_document(
    *,
    firestore_client,
    submission_id: str,
) -> tuple:
    submission_ref = firestore_client.collection('submissions').document(submission_id)
    submission_snapshot = submission_ref.get()
    if not submission_snapshot.exists:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail='Submission not found.',
        )

    submission_data = submission_snapshot.to_dict() or {}
    return submission_ref, submission_data


app = FastAPI(title='VANAVIL S3 Signer API')

app.add_middleware(
    CORSMiddleware,
    allow_origins=get_allowed_origins(),
    allow_origin_regex=get_allowed_origin_regex(),
    allow_credentials=True,
    allow_methods=['GET', 'POST', 'OPTIONS'],
    allow_headers=['*'],
)


@app.get('/health')
def health_check() -> dict[str, str]:
    return {'status': 'ok'}


@app.get('/child-auth/active-children')
def list_active_children() -> dict[str, list[dict[str, str | int]]]:
    firestore_client = get_firestore_client()
    children: list[ChildDirectoryItem] = []

    for child_snapshot in firestore_client.collection('children').stream():
        child_data = child_snapshot.to_dict() or {}
        if str(child_data.get('status', '')).strip().lower() != 'active':
            continue

        children.append(
            build_child_directory_item(
                child_id=child_snapshot.id,
                child_data=child_data,
            )
        )

    children.sort(key=lambda item: (item.name.lower(), item.id))
    return {'children': [child.model_dump() for child in children]}


@app.post('/child-auth/verify-pin')
def verify_child_pin(payload: VerifyChildPinRequest) -> dict[str, str]:
    child_id = require_request_string(payload.childId, 'childId')
    pin = require_four_digit_pin(payload.pin)

    firestore_client = get_firestore_client()
    child_ref, child_data = load_child_profile(
        firestore_client=firestore_client,
        child_id=child_id,
    )
    ensure_active_child(child_data)

    pin_hash = str(child_data.get('pinCodeHash', '')).strip()
    if not pin_hash:
        raise HTTPException(
            status_code=status.HTTP_412_PRECONDITION_FAILED,
            detail='PIN has not been set for this child.',
        )

    if not verify_child_pin_hash(pin, pin_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail='Invalid PIN.',
        )

    child_ref.update(
        {
            'lastLoginAt': firestore.SERVER_TIMESTAMP,
            'updatedAt': firestore.SERVER_TIMESTAMP,
        }
    )

    return {
        'token': create_child_custom_token(child_id),
        'childId': child_id,
    }


@app.post('/admin/children/set-pin')
def set_child_pin(
    payload: SetChildPinRequest,
    decoded_token: dict = Depends(require_admin_user),
) -> dict[str, bool]:
    child_id = require_request_string(payload.childId, 'childId')
    pin = require_four_digit_pin(payload.pin)

    firestore_client = get_firestore_client()
    child_ref, child_data = load_child_profile(
        firestore_client=firestore_client,
        child_id=child_id,
    )

    if str(child_data.get('adminId', '')).strip() != str(decoded_token.get('uid', '')).strip():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail='Only the owning admin can set this child PIN.',
        )

    child_ref.update(
        {
            'pinCodeHash': hash_child_pin(pin),
            'pinUpdatedAt': firestore.SERVER_TIMESTAMP,
            'updatedAt': firestore.SERVER_TIMESTAMP,
        }
    )

    return {'success': True}


@app.post('/attachments/upload-url')
def create_upload_url(
    payload: UploadUrlRequest,
    decoded_token: dict = Depends(require_admin_user),
) -> dict[str, str]:
    if not payload.taskId.strip() or not payload.fileName.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail='taskId and fileName are required to prepare an upload.',
        )

    settings = get_s3_settings()
    object_key = build_object_key(
        uid=decoded_token['uid'],
        task_id=payload.taskId.strip(),
        file_name=payload.fileName.strip(),
    )
    content_type = (payload.contentType or '').strip() or 'application/octet-stream'
    s3_client = get_s3_client()
    upload_url = s3_client.generate_presigned_url(
        ClientMethod='put_object',
        Params={
            'Bucket': settings.bucket,
            'Key': object_key,
            'ContentType': content_type,
            'Metadata': {
                'uploadedBy': decoded_token['uid'],
                'taskId': payload.taskId.strip(),
                'originalFileName': sanitize_file_name(payload.fileName),
            },
        },
        ExpiresIn=900,
    )

    return {
        'bucket': settings.bucket,
        'region': settings.region,
        'objectKey': object_key,
        'contentType': content_type,
        'uploadUrl': upload_url,
    }


@app.post('/attachments/upload')
async def upload_attachment(
    taskId: Annotated[str, Form()],
    file: Annotated[UploadFile, File()],
    fileName: Annotated[str | None, Form()] = None,
    contentType: Annotated[str | None, Form()] = None,
    decoded_token: dict = Depends(require_admin_user),
) -> dict[str, str]:
    normalized_task_id = taskId.strip()
    normalized_file_name = (fileName or file.filename or '').strip()
    if not normalized_task_id or not normalized_file_name:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail='taskId and fileName are required to upload an attachment.',
        )

    normalized_content_type = (
        (contentType or file.content_type or '').strip()
        or 'application/octet-stream'
    )
    settings = get_s3_settings()
    object_key = build_object_key(
        uid=decoded_token['uid'],
        task_id=normalized_task_id,
        file_name=normalized_file_name,
    )
    file_bytes = await file.read()

    s3_client = get_s3_client()
    s3_client.put_object(
        Bucket=settings.bucket,
        Key=object_key,
        Body=file_bytes,
        ContentType=normalized_content_type,
        Metadata={
            'uploadedBy': decoded_token['uid'],
            'taskId': normalized_task_id,
            'originalFileName': sanitize_file_name(normalized_file_name),
        },
    )

    return {
        'bucket': settings.bucket,
        'region': settings.region,
        'objectKey': object_key,
        'contentType': normalized_content_type,
    }


@app.post('/attachments/download-url')
def create_download_url(
    payload: DownloadUrlRequest,
    decoded_token: dict = Depends(require_admin_user),
) -> dict[str, str]:
    object_key = ensure_owned_attachment_key(decoded_token['uid'], payload.objectKey)
    settings = get_s3_settings()
    file_name = sanitize_file_name(payload.fileName or 'attachment')
    content_type = (payload.contentType or '').strip() or None
    s3_client = get_s3_client()
    download_url = s3_client.generate_presigned_url(
        ClientMethod='get_object',
        Params={
            'Bucket': settings.bucket,
            'Key': object_key,
            'ResponseContentType': content_type,
            'ResponseContentDisposition': f'inline; filename="{file_name}"',
        },
        ExpiresIn=300,
    )

    return {'downloadUrl': download_url}


@app.post('/attachments/child-download-url')
def create_child_download_url(
    payload: ChildDownloadUrlRequest,
    decoded_token: dict = Depends(require_child_user),
) -> dict[str, str]:
    requested_child_id = payload.childId.strip()
    requested_task_id = payload.taskId.strip()
    requested_assignment_id = payload.assignmentId.strip()
    requested_object_key = payload.objectKey.strip()

    if (
        not requested_child_id
        or not requested_task_id
        or not requested_assignment_id
        or not requested_object_key
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail='childId, taskId, assignmentId, and objectKey are required.',
        )

    authenticated_child_id = str(decoded_token.get('childId', '')).strip()
    if requested_child_id != authenticated_child_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail='The requested childId does not match the authenticated child.',
        )

    firestore_client = get_firestore_client()
    load_child_assignment(
        firestore_client=firestore_client,
        assignment_id=requested_assignment_id,
        child_id=authenticated_child_id,
        task_id=requested_task_id,
    )
    attachment = load_task_attachment(
        firestore_client=firestore_client,
        task_id=requested_task_id,
        object_key=requested_object_key,
    )

    settings = get_s3_settings()
    file_name = sanitize_file_name(
        payload.fileName or str(attachment.get('fileName', '')).strip() or 'attachment'
    )
    content_type = (
        (payload.contentType or '').strip()
        or str(attachment.get('contentType', '')).strip()
        or None
    )
    s3_client = get_s3_client()
    download_url = s3_client.generate_presigned_url(
        ClientMethod='get_object',
        Params={
            'Bucket': settings.bucket,
            'Key': requested_object_key,
            'ResponseContentType': content_type,
            'ResponseContentDisposition': f'inline; filename="{file_name}"',
        },
        ExpiresIn=300,
    )

    return {'downloadUrl': download_url}


@app.post('/attachments/admin-submission-download-url')
def create_admin_submission_download_url(
    payload: AdminSubmissionDownloadUrlRequest,
    decoded_token: dict = Depends(require_admin_user),
) -> dict[str, str]:
    submission_id = require_request_string(payload.submissionId, 'submissionId')
    firestore_client = get_firestore_client()
    _, submission_data = load_submission_document(
        firestore_client=firestore_client,
        submission_id=submission_id,
    )

    child_id = require_document_string(submission_data, 'childId')
    _, child_data = load_child_profile(
        firestore_client=firestore_client,
        child_id=child_id,
    )

    if str(child_data.get('adminId', '')).strip() != str(decoded_token.get('uid', '')).strip():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail='Only the owning admin can download this submission attachment.',
        )

    object_key = str(
        submission_data.get('objectKey') or submission_data.get('storagePath') or ''
    ).strip()
    if not object_key:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail='Submission is missing its storage path.',
        )

    file_name = sanitize_file_name(
        payload.fileName or str(submission_data.get('fileName', '')).strip() or 'attachment'
    )
    content_type = (
        (payload.contentType or '').strip()
        or str(submission_data.get('contentType', '')).strip()
        or None
    )

    settings = get_s3_settings()
    s3_client = get_s3_client()
    download_url = s3_client.generate_presigned_url(
        ClientMethod='get_object',
        Params={
            'Bucket': settings.bucket,
            'Key': object_key,
            'ResponseContentType': content_type,
            'ResponseContentDisposition': f'inline; filename="{file_name}"',
        },
        ExpiresIn=300,
    )

    return {'downloadUrl': download_url}


@app.post('/attachments/child-upload')
async def upload_child_proof(
    assignmentId: Annotated[str, Form()],
    childId: Annotated[str, Form()],
    file: Annotated[UploadFile, File()],
    fileName: Annotated[str | None, Form()] = None,
    contentType: Annotated[str | None, Form()] = None,
    decoded_token: dict = Depends(require_child_user),
) -> dict[str, str]:
    normalized_assignment_id = require_request_string(assignmentId, 'assignmentId')
    requested_child_id = require_request_string(childId, 'childId')
    authenticated_child_id = require_request_string(decoded_token.get('childId'), 'childId')

    if requested_child_id != authenticated_child_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail='The requested childId does not match the authenticated child.',
        )

    normalized_file_name = require_request_string(fileName or file.filename, 'fileName')
    normalized_content_type = (
        require_request_string(contentType or file.content_type or 'application/octet-stream', 'contentType')
    )

    firestore_client = get_firestore_client()
    assignment_data = load_child_assignment(
        firestore_client=firestore_client,
        assignment_id=normalized_assignment_id,
        child_id=authenticated_child_id,
    )
    ensure_submittable_assignment(assignment_data)

    file_bytes = await file.read()
    if not file_bytes:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail='file is required.',
        )

    object_key = build_child_submission_object_key(
        child_id=authenticated_child_id,
        assignment_id=normalized_assignment_id,
        file_name=normalized_file_name,
    )
    settings = get_s3_settings()
    s3_client = get_s3_client()
    s3_client.put_object(
        Bucket=settings.bucket,
        Key=object_key,
        Body=file_bytes,
        ContentType=normalized_content_type,
        Metadata={
            'uploadedBy': authenticated_child_id,
            'assignmentId': normalized_assignment_id,
            'taskId': str(assignment_data.get('taskId', '')).strip(),
            'originalFileName': sanitize_file_name(normalized_file_name),
        },
    )

    return {
        'bucket': settings.bucket,
        'region': settings.region,
        'objectKey': object_key,
        'contentType': normalized_content_type,
    }


@app.post('/child-submissions/submit')
def submit_child_proof(
    payload: ChildSubmissionRequest,
    decoded_token: dict = Depends(require_child_user),
) -> dict[str, int | bool | str]:
    assignment_id = require_request_string(payload.assignmentId, 'assignmentId')
    requested_child_id = require_request_string(payload.childId, 'childId')
    authenticated_child_id = require_request_string(decoded_token.get('childId'), 'childId')
    normalized_note = normalize_note(payload.note)

    if requested_child_id != authenticated_child_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail='The requested childId does not match the authenticated child.',
        )

    firestore_client = get_firestore_client()
    assignment_data = load_child_assignment(
        firestore_client=firestore_client,
        assignment_id=assignment_id,
        child_id=authenticated_child_id,
        task_id=(payload.taskId or None),
    )
    ensure_submittable_assignment(assignment_data)

    if not payload.attachments and not normalized_note:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail='At least one attachment or a note is required.',
        )

    settings = get_s3_settings()
    s3_client = get_s3_client()
    normalized_task_id = require_document_string(assignment_data, 'taskId')
    submissions_collection = firestore_client.collection('submissions')
    assignment_ref = firestore_client.collection('assignments').document(assignment_id)
    batch = firestore_client.batch()

    if payload.attachments:
        for attachment in payload.attachments:
            object_key = require_request_string(attachment.objectKey, 'attachments.objectKey')
            file_name = require_request_string(attachment.fileName, 'attachments.fileName')
            content_type = require_request_string(attachment.contentType, 'attachments.contentType')
            size_bytes = require_non_negative_int(attachment.sizeBytes, 'attachments.sizeBytes')
            expected_prefix = get_child_submission_prefix(authenticated_child_id, assignment_id)
            if not object_key.startswith(expected_prefix):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail='One or more attachments do not belong to this assignment submission.',
                )

            try:
                s3_client.head_object(Bucket=settings.bucket, Key=object_key)
            except Exception as error:  # pragma: no cover - boto3 passthrough
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail=f'Uploaded attachment not found in S3: {file_name}',
                ) from error

            submission_ref = submissions_collection.document()
            batch.set(
                submission_ref,
                {
                    'assignmentId': assignment_id,
                    'taskId': normalized_task_id,
                    'childId': authenticated_child_id,
                    'proofType': infer_proof_type(content_type),
                    'storagePath': object_key,
                    'objectKey': object_key,
                    'fileName': sanitize_file_name(file_name),
                    'fileUrl': '',
                    'contentType': content_type,
                    'sizeBytes': size_bytes,
                    'note': normalized_note,
                    'uploadedAt': firestore.SERVER_TIMESTAMP,
                },
            )
    else:
        submission_ref = submissions_collection.document()
        batch.set(
            submission_ref,
            {
                'assignmentId': assignment_id,
                'taskId': normalized_task_id,
                'childId': authenticated_child_id,
                'proofType': 'text',
                'storagePath': '',
                'objectKey': '',
                'fileName': 'explanation.txt',
                'fileUrl': '',
                'contentType': 'text/plain',
                'sizeBytes': 0,
                'note': normalized_note,
                'uploadedAt': firestore.SERVER_TIMESTAMP,
            },
        )

    batch.update(
        assignment_ref,
        {
            'status': 'submitted',
            'submittedAt': firestore.SERVER_TIMESTAMP,
            'updatedAt': firestore.SERVER_TIMESTAMP,
        },
    )
    batch.commit()

    return {
        'success': True,
        'assignmentId': assignment_id,
        'submissionCount': len(payload.attachments),
    }


@app.post('/attachments/delete')
def delete_objects(
    payload: DeleteObjectsRequest,
    decoded_token: dict = Depends(require_admin_user),
) -> dict[str, int]:
    owned_keys = [
        ensure_owned_attachment_key(decoded_token['uid'], key)
        for key in payload.attachmentKeys
        if key.strip()
    ]
    if not owned_keys:
        return {'deletedCount': 0}

    settings = get_s3_settings()
    s3_client = get_s3_client()
    s3_client.delete_objects(
        Bucket=settings.bucket,
        Delete={
            'Objects': [{'Key': key} for key in owned_keys],
            'Quiet': True,
        },
    )
    return {'deletedCount': len(owned_keys)}