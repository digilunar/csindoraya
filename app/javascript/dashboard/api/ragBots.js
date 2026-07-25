import ApiClient from './ApiClient';

class RagBotsAPI extends ApiClient {
  constructor() {
    super('rag_bots', { accountScoped: true });
  }
}

export default new RagBotsAPI();
