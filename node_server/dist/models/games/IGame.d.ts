export declare enum GameType {
    SCRABBLE_CLASSIC = "SCRABBLE_CLASSIC",
    SCRABBLE_DUPLICATE = "SCRABBLE_DUPLICATE",
    BOGGLE = "BOGGLE",
    YAM = "YAM",
    DAMES = "DAMES",
    TICTACJONGH = "TICTACJONGH"
}
export declare enum GameStatus {
    WAITING_FOR_PLAYERS = "WAITING_FOR_PLAYERS",
    PLAYING = "PLAYING",
    PAUSED = "PAUSED",
    FINISHED = "FINISHED"
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
    id: string;
    type: GameType;
    hostId: string;
    players: Player[];
    status: GameStatus;
    currentPlayerIndex: number;
    turnNumber: number;
    minPlayers: number;
    maxPlayers: number;
    addPlayer(player: Player): boolean;
    removePlayer(playerId: string): boolean;
    hasPlayer(playerId: string): boolean;
    getPlayer(playerId: string): Player | undefined;
    start(): void;
    handleMove(playerId: string, move: any): MoveResult;
    passTurn(playerId: string): void;
    isPlayerTurn(playerId: string): boolean;
    canStart(): boolean;
    isFinished(): boolean;
    getStateForPlayer(playerId: string): any;
    serialize(): string;
    getMinutesPlayed(): number;
    getWinner(): Player | null;
}
//# sourceMappingURL=IGame.d.ts.map