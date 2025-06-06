# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Imports', type: :request do
  before do
    stub_request(:any, 'https://api.github.com/repos/Freika/dawarich/tags')
      .to_return(status: 200, body: '[{"name": "1.0.0"}]', headers: {})
  end

  describe 'GET /imports' do
    context 'when user is logged in' do
      let(:user) { create(:user) }

      before do
        sign_in user
      end

      it 'returns http success' do
        get imports_path

        expect(response).to have_http_status(200)
      end

      context 'when user has imports' do
        let!(:import) { create(:import, user:) }

        it 'displays imports' do
          get imports_path

          expect(response.body).to include(import.name)
        end
      end
    end
  end

  describe 'POST /imports' do
    context 'when user is logged in' do
      let(:user) { create(:user) }

      before { sign_in user }

      context 'when importing owntracks data' do
        let(:file) { fixture_file_upload('owntracks/2024-03.rec', 'text/plain') }
        let(:blob) { create_blob_for_file(file) }
        let(:signed_id) { generate_signed_id_for_blob(blob) }

        it 'queues import job' do
          allow(ActiveStorage::Blob).to receive(:find_signed).with(signed_id).and_return(blob)

          expect do
            post imports_path, params: { import: { source: 'owntracks', files: [signed_id] } }
          end.to have_enqueued_job(Import::ProcessJob).on_queue('imports').at_least(1).times
        end

        it 'creates a new import' do
          allow(ActiveStorage::Blob).to receive(:find_signed).with(signed_id).and_return(blob)

          expect do
            post imports_path, params: { import: { source: 'owntracks', files: [signed_id] } }
          end.to change(user.imports, :count).by(1)

          expect(response).to redirect_to(imports_path)
        end
      end

      context 'when importing gpx data' do
        let(:file) { fixture_file_upload('gpx/gpx_track_single_segment.gpx', 'application/gpx+xml') }
        let(:blob) { create_blob_for_file(file) }
        let(:signed_id) { generate_signed_id_for_blob(blob) }

        it 'queues import job' do
          allow(ActiveStorage::Blob).to receive(:find_signed).with(signed_id).and_return(blob)

          expect do
            post imports_path, params: { import: { source: 'gpx', files: [signed_id] } }
          end.to have_enqueued_job(Import::ProcessJob).on_queue('imports').at_least(1).times
        end

        it 'creates a new import' do
          allow(ActiveStorage::Blob).to receive(:find_signed).with(signed_id).and_return(blob)

          expect do
            post imports_path, params: { import: { source: 'gpx', files: [signed_id] } }
          end.to change(user.imports, :count).by(1)

          expect(response).to redirect_to(imports_path)
        end
      end

      context 'when an error occurs during import creation' do
        let(:file1) { fixture_file_upload('owntracks/2024-03.rec', 'text/plain') }
        let(:file2) { fixture_file_upload('gpx/gpx_track_single_segment.gpx', 'application/gpx+xml') }
        let(:blob1) { create_blob_for_file(file1) }
        let(:blob2) { create_blob_for_file(file2) }
        let(:signed_id1) { generate_signed_id_for_blob(blob1) }
        let(:signed_id2) { generate_signed_id_for_blob(blob2) }

        it 'deletes any created imports' do
          # The first blob should be found correctly
          allow(ActiveStorage::Blob).to receive(:find_signed).with(signed_id1).and_return(blob1)

          # The second blob find will raise an error
          allow(ActiveStorage::Blob).to receive(:find_signed).with(signed_id2).and_raise(StandardError, 'Test error')

          # Allow ExceptionReporter to be called without actually calling it
          allow(ExceptionReporter).to receive(:call)

          # The request should not ultimately create any imports
          expect do
            post imports_path, params: { import: { source: 'owntracks', files: [signed_id1, signed_id2] } }
          end.not_to change(Import, :count)

          # Check that we were redirected with an error message
          expect(response).to have_http_status(422)
          # Just check that we have an alert message, not its exact content
          # since error handling might transform the message
          expect(flash[:alert]).not_to be_nil
        end
      end
    end
  end

  describe 'GET /imports/new' do
    context 'when user is logged in' do
      let(:user) { create(:user) }

      before { sign_in user }

      it 'returns http success' do
        get new_import_path

        expect(response).to have_http_status(200)
      end
    end
  end

  describe 'DELETE /imports/:id' do
    context 'when user is logged in' do
      let(:user) { create(:user) }
      let!(:import) { create(:import, user:) }

      before { sign_in user }

      it 'deletes the import' do
        expect do
          delete import_path(import)
        end.to change(user.imports, :count).by(-1)

        expect(response).to redirect_to(imports_path)
      end
    end
  end

  describe 'GET /imports/:id/edit' do
    context 'when user is logged in' do
      let(:user) { create(:user) }
      let(:import) { create(:import, user:) }

      before { sign_in user }

      it 'returns http success' do
        get edit_import_path(import)

        expect(response).to have_http_status(200)
      end
    end
  end

  describe 'PATCH /imports/:id' do
    context 'when user is logged in' do
      let(:user) { create(:user) }
      let(:import) { create(:import, user:) }

      before { sign_in user }

      it 'updates the import' do
        patch import_path(import), params: { import: { name: 'New Name' } }

        expect(import.reload.name).to eq('New Name')
        expect(response).to redirect_to(imports_path)
      end
    end
  end

  # Helper methods for creating ActiveStorage blobs and signed IDs in tests
  def create_blob_for_file(file)
    ActiveStorage::Blob.create_and_upload!(
      io: file.open,
      filename: file.original_filename,
      content_type: file.content_type
    )
  end

  def generate_signed_id_for_blob(blob)
    blob.signed_id
  end
end
