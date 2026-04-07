import { GameType, GameStatus } from './IGame.js';
export class BaseGame {
    id;
    hostId;
    players = [];
    status = GameStatus.WAITING_FOR_PLAYERS;
    currentPlayerIndex = 0;
    turnNumber = 0;
    createdAt;
    constructor(id, hostId) {
        this.id = id;
        this.hostId = hostId;
        this.createdAt = new Date();
    }
    // Implémentations communes
    addPlayer(player) {
        if (this.players.length >= this.maxPlayers) {
            return false;
        }
        if (this.hasPlayer(player.id)) {
            return false;
        }
        this.players.push(player);
        return true;
    }
    removePlayer(playerId) {
        const index = this.players.findIndex(p => p.id === playerId);
        if (index === -1)
            return false;
        this.players.splice(index, 1);
        // Ajuster l'index du joueur actuel si nécessaire
        if (this.currentPlayerIndex >= this.players.length) {
            this.currentPlayerIndex = 0;
        }
        return true;
    }
    hasPlayer(playerId) {
        return this.players.some(p => p.id === playerId);
    }
    getPlayer(playerId) {
        return this.players.find(p => p.id === playerId);
    }
    isPlayerTurn(playerId) {
        if (this.players.length === 0)
            return false;
        return this.players[this.currentPlayerIndex]?.id === playerId;
    }
    canStart() {
        return this.players.length >= this.minPlayers &&
            this.status === GameStatus.WAITING_FOR_PLAYERS;
    }
    isFinished() {
        return this.status === GameStatus.FINISHED;
    }
    getMinutesPlayed() {
        const now = new Date();
        return Math.floor((now.getTime() - this.createdAt.getTime()) / 60000);
    }
    getWinner() {
        if (!this.isFinished())
            return null;
        // Par défaut : score le plus élevé
        return this.players.reduce((winner, player) => {
            return player.score > (winner?.score || 0) ? player : winner;
        }, null);
    }
    serialize() {
        return JSON.stringify(this);
    }
}
//# sourceMappingURL=BaseGame.js.map