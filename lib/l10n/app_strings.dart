class AppStrings {
  const AppStrings._();

  static const appTitle = 'O Cajado';
  static const dashboardTitle = 'O Cajado';
  static const sermons = 'Sermões';
  static const untitledSermon = 'Sem título';
  static const newSermon = 'Novo Sermão';
  static const importSpreadsheet = 'Importar Planilha';
  static const settings = 'Configurações';
  static const trash = 'Lixeira';
  static const dataManagement = 'Gerenciamento de Dados';
  static const exportData = 'Exportar Dados';
  static const exportDataHelp = 'Salvar uma planilha .xlsx com seus sermões';
  static const exportSuccess = 'Planilha salva com sucesso.';
  static const exportFailure = 'Erro ao exportar. Tente novamente.';
  static const exportInProgress = 'Exportando sermões...';
  static const importDataHelp = 'Importar sermões de uma planilha .xlsx';
  static const openTrashHelp = 'Restaurar ou excluir sermões da lixeira';
  static const clearDeliveryHistory = 'Limpar Histórico de Pregações';
  static const clearDeliveryHistoryHelp =
      'Mover todos os sermões para a lixeira';
  static const clearDeliveryHistoryQuestion =
      'Mover todos os sermões para a lixeira?';
  static const clearDeliveryHistoryBody =
      'Esta ação pode ser desfeita restaurando os sermões da lixeira.';
  static const moveAllToTrashConfirm = 'Mover para Lixeira';
  static const deliveryHistoryCleared =
      'Todos os sermões foram movidos para a lixeira.';
  static const searchHint = 'Pesquisar sermões...';
  static const all = 'Todos';
  static const archived = 'Arquivados';
  static const pinned = 'Fixados';
  static const archivedSermons = 'Sermões arquivados';
  static const noArchivedSermons = 'Nenhum sermão arquivado';
  static const archiveDatePrefix = 'Arquivado em';
  static const noSermonsFound = 'Nenhum sermão encontrado.';
  static const noSermonsFoundPlain = 'Nenhum sermão encontrado';
  static const errorPrefix = 'Erro';
  static const loadErrorPrefix = 'Erro ao carregar';
  static const createFirstSermon =
      'Use Novo Sermão para criar seu primeiro sermão';
  static const maxPinned = 'Máximo de 5 sermões fixados';
  static const pinSermon = 'Fixar sermão';
  static const unpinSermon = 'Desafixar sermão';
  static const moveToTrash = 'Mover para lixeira';
  static const movedToTrash = 'Sermão movido para a lixeira.';
  static const sermonMovedToTrash = 'Sermão movido para a lixeira.';
  static const sermonArchived = 'Sermão arquivado.';
  static const undo = 'Desfazer';
  static const restore = 'Restaurar';
  static const restored = 'Sermão restaurado.';
  static const delete = 'Excluir';
  static const cancel = 'Cancelar';
  static const save = 'Salvar';
  static const sermonSaved = 'Sermão salvo.';
  static const discard = 'Descartar';
  static const selectAll = 'Selecionar todos';
  static const selectedSuffix = 'selecionados';
  static const changeStatus = 'Alterar Status';
  static const bulkMoveToTrash = 'Mover para Lixeira';
  static const bulkMovedToTrashSuffix = 'sermões movidos para a lixeira.';
  static const bulkRestoredSuffix = 'sermões restaurados.';
  static const deletePermanently = 'Excluir permanentemente';
  static const cannotUndo = 'Esta ação não pode ser desfeita.';
  static const emptyTrash = 'Esvaziar lixeira';
  static const emptyTrashQuestion = 'Esvaziar lixeira?';
  static const emptyTrashBody =
      'Todos os sermões na lixeira serão excluídos definitivamente e não poderão ser recuperados.';
  static const deletePermanentlyQuestion = 'Excluir definitivamente?';
  static const deletePermanentlyBody =
      'Este sermão será excluído definitivamente e não poderá ser recuperado.';
  static const deleteSinglePermanentlyBody =
      'Excluir permanentemente? Esta ação não pode ser desfeita.';
  static const trashEmpty = 'A lixeira está vazia';
  static const trashDatePrefix = 'Movido em';
  static const pinnedSwipeDisabled = 'Sermões fixados não podem ser arquivados';

  static const titleHint = 'Tema do sermão';
  static const duplicateTitleWarning = 'Já existe um sermão com este tema.';
  static const textoHint = 'Texto (opcional)';
  static const dateLabel = 'Data';
  static const noDate = 'Sem data';
  static const tagHint = '+ Tag';
  static const sermonIdLabel = 'ID do sermão';
  static const sermonIdDuplicate = 'Este ID já está em uso por outro sermão.';
  static const sermonIdInvalid = 'Use apenas números inteiros positivos.';
  static const saveDraftQuestion = 'Salvar sermão?';
  static const saveDraftBody =
      'Você preencheu informações neste sermão. Deseja salvar ou descartar?';
  static const pulpitHistoryTooltip = 'Histórico de pregações';
  static const pulpitModeTooltip = 'Modo Púlpito';
  static const editorPlaceholder = 'Comece a escrever seu sermão...';
  static const scriptureDetectedBody =
      'Referência bíblica detectada. A funcionalidade de exibição do texto completo será habilitada com a Bíblia offline.';
  static const close = 'Fechar';

  static const idMatch = 'ID';
  static const titleMatch = 'Tema';
  static const textoMatch = 'Texto';
  static const dateMatch = 'Data';

  static const importReadingFile = 'Lendo arquivo...';
  static const importProcessingRows = 'Processando linhas...';
  static const importCreatingSermons = 'Criando sermões...';
  static const importOverlayCounter = 'Importando sermão';
  static const importCancelled = 'Importação cancelada.';
  static const importFailure =
      'Erro ao importar. Verifique o arquivo e tente novamente.';
  static const importProcessingCounter = 'Processando sermão';
  static const importDone = 'Concluído';
  static const importNoFile = 'Nenhum arquivo selecionado.';
  static const importReadFailure = 'Não foi possível ler a planilha.';
  static const importSuccessSuffix = 'sermões importados com sucesso.';
  static const importPartialMiddle = 'sermões importados.';
  static const importPartialSuffix = 'linhas ignoradas por erro.';

  static const historyTitle = 'Histórico de pregações';
  static const sermonNotFound = 'Sermão não encontrado';
  static const neverDelivered = 'Este sermão ainda não foi pregado';
  static const pulpitHistoryHelp =
      'Use o Modo Púlpito para registrar\npregações automaticamente';
  static const exitPulpitMode = 'Sair do modo púlpito';

  static const appearance = 'Aparência';
  static const system = 'Sistema';
  static const followDevice = 'Seguir configuração do dispositivo';
  static const light = 'Claro';
  static const lightAlways = 'Modo claro sempre ativo';
  static const dark = 'Escuro';
  static const darkAlways = 'Modo escuro sempre ativo';
  static const fontSize = 'Tamanho da fonte';
  static const fontSizeHelp = 'Ajuste o tamanho do texto em todo o aplicativo';
  static const previewText = 'Texto de exemplo para visualização';
  static const aboutVersion = 'O Cajado v1.0.0';
  static const statusDraft = 'Rascunho';
  static const statusReady = 'Pronto';
  static const statusDelivered = 'Pregado';
  static const fontSmall = 'Pequeno';
  static const fontMedium = 'Médio';
  static const fontLarge = 'Grande';
  static const now = 'agora mesmo';
  static const oneYearAgo = 'há 1 ano';
  static const yearsAgoSuffix = 'anos';
  static const oneMonthAgo = 'há 1 mês';
  static const monthsAgoSuffix = 'meses';
  static const oneDayAgo = 'há 1 dia';
  static const daysAgoSuffix = 'dias';
  static const oneHourAgo = 'há 1 hora';
  static const hoursAgoSuffix = 'horas';
  static const oneMinuteAgo = 'há 1 minuto';
  static const minutesAgoSuffix = 'minutos';
}
