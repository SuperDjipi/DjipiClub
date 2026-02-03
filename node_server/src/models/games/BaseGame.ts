import { type IGame, GameType, GameStatus, type Player, type MoveResult } from './IGame.js';

export abstract class BaseGame implements IGame {
    id: string;
    abstract type: GameType;
    hostId: string;
    
    players: Player[] = [];
    status: GameStatus = GameStatus.WAITING_FOR_PLAYERS;
    currentPlayerIndex: number = 0;
    turnNumber: number = 0;
    
    abstract minPlayers: number;
    abstract maxPlayers: number;
    
    protected createdAt: Date;
    
    constructor(id: string, hostId: string) {
        this.id = id;
        this.hostId = hostId;
        this.createdAt = new Date();
    }
    
    // Implémentations communes
    addPlayer(player: Player): boolean {
        if (this.players.length >= this.maxPlayers) {
            return false;
        }
        if (this.hasPlayer(player.id)) {
            return false;
        }
        this.players.push(player);
        return true;
    }
    
    removePlayer(playerId: string): boolean {
        const index = this.players.findIndex(p => p.id === playerId);
        if (index === -1) return false;
        
        this.players.splice(index, 1);
        
        // Ajuster l'index du joueur actuel si nécessaire
        if (this.currentPlayerIndex >= this.players.length) {
            this.currentPlayerIndex = 0;
        }
        
        return true;
    }
    
    hasPlayer(playerId: string): boolean {
        return this.players.some(p => p.id === playerId);
    }
    
    getPlayer(playerId: string): Player | undefined {
        return this.players.find(p => p.id === playerId);
    }
    
    isPlayerTurn(playerId: string): boolean {
        if (this.players.length === 0) return false;
        return this.players[this.currentPlayerIndex]?.id === playerId;
    }
    
    canStart(): boolean {
        return this.players.length >= this.minPlayers && 
               this.status === GameStatus.WAITING_FOR_PLAYERS;
    }
    
    isFinished(): boolean {
        return this.status === GameStatus.FINISHED;
    }
    
    getMinutesPlayed(): number {
        const now = new Date();
        return Math.floor((now.getTime() - this.createdAt.getTime()) / 60000);
    }
    
    getWinner(): Player | null {
        if (!this.isFinished()) return null;
        
        // Par défaut : score le plus élevé
        return this.players.reduce((winner, player) => {
            return player.score > (winner?.score || 0) ? player : winner;
        }, null as Player | null);
    }
    
    serialize(): string {
        return JSON.stringify(this);
    }
    
    // Méthodes abstraites (à implémenter par chaque jeu)
    abstract start(): void;
    abstract handleMove(playerId: string, move: any): MoveResult;
    abstract passTurn(playerId: string): void;
    abstract getStateForPlayer(playerId: string): any;
}