export enum GameType {
    SCRABBLE_CLASSIC = 'SCRABBLE_CLASSIC',
    SCRABBLE_DUPLICATE = 'SCRABBLE_DUPLICATE',
    BOGGLE = 'BOGGLE',
    YAM = 'YAM',
    DAMES = 'DAMES',
    TICTACJONGH = 'TICTACJONGH'
}

export enum GameStatus {
    WAITING_FOR_PLAYERS = 'WAITING_FOR_PLAYERS',
    PLAYING = 'PLAYING',
    PAUSED = 'PAUSED',
    FINISHED = 'FINISHED'
}

export interface Player {
    id: string;
    name: string;
    score: number;
    isActive: boolean;
}

export interface MoveResult {
    valid: boolean;
    newState?: any;
    score?: number;
    errors?: string[];
}

export interface IGame {
    // Identité
    id: string;
    type: GameType;
    hostId: string;
    
    // État
    players: Player[];
    status: GameStatus;
    currentPlayerIndex: number;
    turnNumber: number;
    
    // Configuration
    minPlayers: number;
    maxPlayers: number;
    
    // Méthodes de gestion des joueurs
    addPlayer(player: Player): boolean;
    removePlayer(playerId: string): boolean;
    hasPlayer(playerId: string): boolean;
    getPlayer(playerId: string): Player | undefined;
    
    // Méthodes de jeu
    start(): void;
    handleMove(playerId: string, move: any): MoveResult;
    passTurn(playerId: string): void;
    
    // Vérifications
    isPlayerTurn(playerId: string): boolean;
    canStart(): boolean;
    isFinished(): boolean;
    
    // Sérialisation (pour sauvegarde)
    getStateForPlayer(playerId: string): any;
    serialize(): string;
    
    // Métadonnées
    getMinutesPlayed(): number;
    getWinner(): Player | null;
}