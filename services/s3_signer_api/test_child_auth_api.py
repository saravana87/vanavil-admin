from unittest.mock import patch

from fastapi.testclient import TestClient

import main


class FakeSnapshot:
    def __init__(self, data=None, doc_id=None):
        self._data = data
        self.id = doc_id
        self.exists = data is not None

    def to_dict(self):
        return self._data


class FakeDocumentRef:
    def __init__(self, store, collection_name, doc_id):
        self._store = store
        self._collection_name = collection_name
        self._doc_id = doc_id

    def get(self):
        return FakeSnapshot(self._store.get(self._collection_name, {}).get(self._doc_id))

    def update(self, data):
        self._store[self._collection_name][self._doc_id].update(data)

    def set(self, data):
        self._store.setdefault(self._collection_name, {})[self._doc_id] = data


class FakeCollection:
    def __init__(self, store, collection_name):
        self._store = store
        self._collection_name = collection_name
        self._counter = 0

    def document(self, doc_id=None):
        if doc_id is None:
            self._counter += 1
            doc_id = f'{self._collection_name}_{self._counter}'
        return FakeDocumentRef(self._store, self._collection_name, doc_id)

    def stream(self):
        for doc_id, data in self._store.get(self._collection_name, {}).items():
            yield FakeSnapshot(data, doc_id=doc_id)


class FakeFirestore:
    def __init__(self, store):
        self._store = store
        self._collections = {}

    def collection(self, collection_name):
        if collection_name not in self._collections:
            self._collections[collection_name] = FakeCollection(self._store, collection_name)
        return self._collections[collection_name]

    def batch(self):
        return FakeBatch()


class FakeBatch:
    def __init__(self):
        self._operations = []

    def set(self, document_ref, data):
        self._operations.append(('set', document_ref, data))

    def update(self, document_ref, data):
        self._operations.append(('update', document_ref, data))

    def commit(self):
        for operation, document_ref, data in self._operations:
            if operation == 'set':
                document_ref.set(data)
            else:
                document_ref.update(data)


class FakeS3Client:
    def __init__(self):
        self.objects = {}

    def put_object(self, Bucket, Key, Body, ContentType=None, Metadata=None):
        self.objects[(Bucket, Key)] = {
            'body': Body,
            'contentType': ContentType,
            'metadata': Metadata or {},
        }

    def head_object(self, Bucket, Key):
        if (Bucket, Key) not in self.objects:
            raise FileNotFoundError(Key)
        return {'ContentLength': len(self.objects[(Bucket, Key)]['body'])}

    def generate_presigned_url(self, ClientMethod, Params, ExpiresIn):
        return f"https://example.invalid/{Params['Key']}?expires={ExpiresIn}"


def build_store():
    return {
        'admins': {
            'admin_1': {'email': 'admin@example.com'},
        },
        'children': {
            'child_1': {
                'adminId': 'admin_1',
                'status': 'active',
                'pinCodeHash': main.hash_child_pin('1234'),
            },
            'child_2': {
                'adminId': 'admin_2',
                'status': 'inactive',
                'pinCodeHash': main.hash_child_pin('1234'),
            },
        },
        'assignments': {
            'assignment_1': {
                'childId': 'child_1',
                'taskId': 'task_1',
                'status': 'assigned',
                'assignedBy': 'admin_1',
            },
        },
        'submissions': {},
    }


def main_test():
    store = build_store()
    fake_s3 = FakeS3Client()
    client = TestClient(main.app)

    with (
        patch.object(main, 'get_firestore_client', return_value=FakeFirestore(store)),
        patch.object(main, 'create_child_custom_token', return_value='child-token-1'),
        patch.object(main, 'get_s3_client', return_value=fake_s3),
        patch.object(
            main,
            'get_s3_settings',
            return_value=main.S3Settings(
                bucket='vanavil',
                region='us-east-1',
                access_key_id='key',
                secret_access_key='secret',
            ),
        ),
    ):
        main.app.dependency_overrides[main.require_admin_user] = lambda: {'uid': 'admin_1'}
        main.app.dependency_overrides[main.require_child_user] = lambda: {
            'uid': 'child_child_1',
            'role': 'child',
            'childId': 'child_1',
            'childDoc': store['children']['child_1'],
        }

        active_children_response = client.get('/child-auth/active-children')
        assert active_children_response.status_code == 200, active_children_response.text
        assert active_children_response.json() == {
            'children': [
                {
                    'id': 'child_1',
                    'name': 'Child',
                    'avatar': 'C',
                    'totalPoints': 0,
                }
            ]
        }

        verify_response = client.post(
            '/child-auth/verify-pin',
            json={'childId': 'child_1', 'pin': '1234'},
        )
        assert verify_response.status_code == 200, verify_response.text
        assert verify_response.json() == {'token': 'child-token-1', 'childId': 'child_1'}
        assert 'lastLoginAt' in store['children']['child_1']

        inactive_response = client.post(
            '/child-auth/verify-pin',
            json={'childId': 'child_2', 'pin': '1234'},
        )
        assert inactive_response.status_code == 403, inactive_response.text

        set_pin_response = client.post(
            '/admin/children/set-pin',
            json={'childId': 'child_1', 'pin': '9876'},
            headers={'Authorization': 'Bearer admin-token'},
        )
        assert set_pin_response.status_code == 200, set_pin_response.text
        assert set_pin_response.json() == {'success': True}
        assert main.verify_child_pin_hash('9876', store['children']['child_1']['pinCodeHash'])

        upload_response = client.post(
            '/attachments/child-upload',
            data={
                'assignmentId': 'assignment_1',
                'childId': 'child_1',
                'fileName': 'proof.txt',
                'contentType': 'text/plain',
            },
            files={'file': ('proof.txt', b'completed the task', 'text/plain')},
            headers={'Authorization': 'Bearer child-token'},
        )
        assert upload_response.status_code == 200, upload_response.text
        upload_json = upload_response.json()
        assert upload_json['bucket'] == 'vanavil'
        assert upload_json['region'] == 'us-east-1'
        assert upload_json['contentType'] == 'text/plain'
        assert upload_json['objectKey'].startswith(
            'task_attachments/child_submissions/child_1/assignment_1/'
        )

        submit_response = client.post(
            '/child-submissions/submit',
            json={
                'assignmentId': 'assignment_1',
                'taskId': 'task_1',
                'childId': 'child_1',
                'note': 'I finished it by writing a short explanation.',
                'attachments': [
                    {
                        'objectKey': upload_json['objectKey'],
                        'fileName': 'proof.txt',
                        'contentType': 'text/plain',
                        'sizeBytes': 18,
                    }
                ],
            },
            headers={'Authorization': 'Bearer child-token'},
        )
        assert submit_response.status_code == 200, submit_response.text
        assert submit_response.json() == {
            'success': True,
            'assignmentId': 'assignment_1',
            'submissionCount': 1,
        }
        assert store['assignments']['assignment_1']['status'] == 'submitted'
        assert 'submittedAt' in store['assignments']['assignment_1']
        assert 'updatedAt' in store['assignments']['assignment_1']
        assert len(store['submissions']) == 1
        submission = next(iter(store['submissions'].values()))
        assert submission['assignmentId'] == 'assignment_1'
        assert submission['taskId'] == 'task_1'
        assert submission['childId'] == 'child_1'
        assert submission['proofType'] == 'file'
        assert submission['storagePath'] == upload_json['objectKey']
        assert submission['fileName'] == 'proof.txt'
        assert submission['contentType'] == 'text/plain'
        assert submission['sizeBytes'] == 18
        assert submission['note'] == 'I finished it by writing a short explanation.'
        assert 'uploadedAt' in submission

        submission_id = next(iter(store['submissions'].keys()))
        admin_download_response = client.post(
            '/attachments/admin-submission-download-url',
            json={'submissionId': submission_id},
            headers={'Authorization': 'Bearer admin-token'},
        )
        assert admin_download_response.status_code == 200, admin_download_response.text
        assert admin_download_response.json() == {
            'downloadUrl': f'https://example.invalid/{upload_json["objectKey"]}?expires=300'
        }

        store['assignments']['assignment_1']['status'] = 'assigned'
        store['submissions'] = {}

        note_only_response = client.post(
            '/child-submissions/submit',
            json={
                'assignmentId': 'assignment_1',
                'taskId': 'task_1',
                'childId': 'child_1',
                'note': 'Only a written explanation this time.',
                'attachments': [],
            },
            headers={'Authorization': 'Bearer child-token'},
        )
        assert note_only_response.status_code == 200, note_only_response.text
        assert note_only_response.json() == {
            'success': True,
            'assignmentId': 'assignment_1',
            'submissionCount': 0,
        }
        assert len(store['submissions']) == 1
        note_submission = next(iter(store['submissions'].values()))
        assert note_submission['proofType'] == 'text'
        assert note_submission['objectKey'] == ''
        assert note_submission['fileName'] == 'explanation.txt'
        assert note_submission['note'] == 'Only a written explanation this time.'

        main.app.dependency_overrides.clear()


if __name__ == '__main__':
    main_test()
    print('child auth api tests passed')