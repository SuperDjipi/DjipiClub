import { type IGame, GameType, GameStatus, type Player, type MoveResult } from './IGame.js';
export declare abstract class BaseGame implements IGame {
    id: string;
    abstract type: GameType;
    hostId: string;
    players: Player[];
    status: GameStatus;
    currentPlayerIndex: number;
    turnNumber: number;
    abstract minPlayers: number;
    abstract maxPlayers: number;
    protected createdAt: Date;
    constructor(id: string, hostId: string);
    addPlayer(player: Player): boolean;
    removePlayer(playerId: string): boolean;
    hasPlayer(playerId: string): boolean;
    getPlayer(playerId: string): Player | undefined;
    isPlayerTurn(playerId: string): boolean;
    canStart(): boolean;
    isFinished(): boolean;
    getMinutesPlayed(): number;
    getWinner(): Player | null;
    serialize(): string;
    abstract start(): void;
    abstract handleMove(playerId: string, move: any): MoveResult;
    abstract passTurn(playerId: string): void;
    abstract getStateForPlayer(playerId: string): any;
}
//# sourceMappingURL=BaseGame.d.ts.map