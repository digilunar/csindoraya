/* global axios */

const types = {
  FETCH_DOCUMENTS: 'FETCH_DOCUMENTS',
  FETCH_DOCUMENTS_SUCCESS: 'FETCH_DOCUMENTS_SUCCESS',
  FETCH_DOCUMENTS_FAILURE: 'FETCH_DOCUMENTS_FAILURE',
  UPLOAD_DOCUMENTS: 'UPLOAD_DOCUMENTS',
  UPLOAD_DOCUMENTS_SUCCESS: 'UPLOAD_DOCUMENTS_SUCCESS',
  UPLOAD_DOCUMENTS_FAILURE: 'UPLOAD_DOCUMENTS_FAILURE',
  DELETE_DOCUMENT: 'DELETE_DOCUMENT',
  DELETE_DOCUMENT_SUCCESS: 'DELETE_DOCUMENT_SUCCESS',
  DELETE_DOCUMENT_FAILURE: 'DELETE_DOCUMENT_FAILURE',
};

const state = {
  documents: [],
  isFetching: false,
  isUploading: false,
  error: null,
};

const getters = {
  getDocuments: _state => _state.documents,
  getIsFetching: _state => _state.isFetching,
  getIsUploading: _state => _state.isUploading,
};

const actions = {
  async get({ commit }, { accountId, ragBotId }) {
    commit(types.FETCH_DOCUMENTS);
    try {
      const response = await axios.get(`/api/v1/accounts/${accountId}/rag/documents`, { params: { rag_bot_id: ragBotId } });
      commit(types.FETCH_DOCUMENTS_SUCCESS, response.data);
      return response;
    } catch (error) {
      commit(types.FETCH_DOCUMENTS_FAILURE, error);
      throw error;
    }
  },

  async upload({ commit }, { accountId, formData }) {
    commit(types.UPLOAD_DOCUMENTS);
    try {
      const response = await axios.post(
        `/api/v1/accounts/${accountId}/rag/documents/bulk_upload`,
        formData,
        {
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        }
      );
      commit(types.UPLOAD_DOCUMENTS_SUCCESS, response.data);
      return response;
    } catch (error) {
      commit(types.UPLOAD_DOCUMENTS_FAILURE, error);
      throw error;
    }
  },

  async delete({ commit }, { accountId, id }) {
    try {
      const response = await axios.delete(`/api/v1/accounts/${accountId}/rag/documents/${id}`);
      commit(types.DELETE_DOCUMENT_SUCCESS, id);
      return response;
    } catch (error) {
      commit(types.DELETE_DOCUMENT_FAILURE, error);
      throw error;
    }
  },
};

const mutations = {
  [types.FETCH_DOCUMENTS](_state) {
    _state.isFetching = true;
  },
  [types.FETCH_DOCUMENTS_SUCCESS](_state, documents) {
    _state.isFetching = false;
    _state.documents = documents;
  },
  [types.FETCH_DOCUMENTS_FAILURE](_state, error) {
    _state.isFetching = false;
    _state.error = error;
  },
  [types.UPLOAD_DOCUMENTS](_state) {
    _state.isUploading = true;
  },
  [types.UPLOAD_DOCUMENTS_SUCCESS](_state) {
    _state.isUploading = false;
  },
  [types.UPLOAD_DOCUMENTS_FAILURE](_state, error) {
    _state.isUploading = false;
    _state.error = error;
  },
  [types.DELETE_DOCUMENT_SUCCESS](_state, id) {
    _state.documents = _state.documents.filter(doc => doc.id !== id);
  },
};

export default {
  namespaced: true,
  state,
  getters,
  actions,
  mutations,
};