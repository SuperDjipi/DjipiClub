import { BaseGame } from '../../models/games/BaseGame.js';
import { GameType, GameStatus } from '../../models/games/IGame.js';
import { createEmptyBoard } from './models/BoardModels.js';
import { createTileBag, drawTiles } from './logic/TileBag.js';
export class ScrabbleClassic extends BaseGame {
    type = GameType.SCRABBLE_CLASSIC;
    minPlayers = 2;
    maxPlayers = 4;
    // État spécifique Scrabble
    board;
    tileBag;
    placedPositions = [];
    forceEndGame = 0;
    constructor(id, hostId) {
        super(id, hostId);
        this.board = createEmptyBoard();
        this.tileBag = createTileBag();
    }
    start() {
        if (!this.canStart()) {
            throw new Error('Impossible de démarrer : pas assez de joueurs');
        }
        // Mélanger les joueurs
        this.players.sort(() => Math.random() - 0.5);
        // Distribuer 7 tuiles à chaque joueur
        let currentBag = this.tileBag;
        this.players = this.players.map(player => {
            const { drawnTiles, newBag } = drawTiles(currentBag, 7);
            currentBag = newBag;
            return {
                ...player,
                rack: drawnTiles,
                isActive: false
            };
        });
        this.tileBag = currentBag;
        // Premier joueur actif
        if (this.players.length > 0) {
            this.players[0].isActive = true;
        }
        this.status = GameStatus.PLAYING;
        this.currentPlayerIndex = 0;
        this.turnNumber = 1;
        console.log(`🎮 Partie Scrabble ${this.id} démarrée avec ${this.players.length} joueurs`);
    }
    handleMove(playerId, move) {
        // Vérifier que c'est le tour du joueur
        if (!this.isPlayerTurn(playerId)) {
            return {
                valid: false,
                errors: ['Ce n\'est pas votre tour']
            };
        }
        const placedTiles = move.placedTiles || [];
        if (placedTiles.length === 0) {
            return {
                valid: false,
                errors: ['Aucune tuile placée']
            };
        }
        // TODO: Validation du mouvement (à implémenter)
        // Pour l'instant, on accepte tous les coups
        // Appliquer le mouvement
        this._applyMove(placedTiles, playerId);
        return {
            valid: true,
            score: 10 // TODO: Calculer le vrai score
        };
    }
    passTurn(playerId) {
        if (!this.isPlayerTurn(playerId)) {
            return;
        }
        // Passer au joueur suivant
        this._nextPlayer();
        console.log(`⏭️ ${playerId} a passé son tour`);
    }
    getStateForPlayer(playerId) {
        const player = this.getScrabblePlayer(playerId);
        return {
            gameState: {
                id: this.id,
                type: this.type,
                board: this.board,
                players: this.players.map(p => ({
                    ...p,
                    rack: p.id === playerId ? p.rack : [] // Cacher les chevalets des autres
                })),
                status: this.status,
                currentPlayerIndex: this.currentPlayerIndex,
                turnNumber: this.turnNumber,
                tileBag: { tileCount: this.tileBag.length } // Juste le nombre
            },
            playerRack: player?.rack || []
        };
    }
    /**
     * Retourne un joueur Scrabble avec son chevalet
     */
    getScrabblePlayer(playerId) {
        return this.players.find(p => p.id === playerId);
    }
    // ========================================================================
    // MÉTHODES PRIVÉES
    // ========================================================================
    _applyMove(placedTiles, playerId) {
        // Placer les tuiles sur le plateau
        for (const { boardPosition, tile } of placedTiles) {
            const { row, col } = boardPosition;
            if (this.board[row] && this.board[row][col]) {
                this.board[row][col].tile = tile;
                this.board[row][col].isLocked = true;
                this.placedPositions.push({ row, col });
            }
        }
        // Retirer les tuiles du chevalet du joueur
        const player = this.getScrabblePlayer(playerId);
        if (player && player.rack) {
            const usedTileIds = placedTiles.map(pt => pt.tile.id);
            player.rack = player.rack.filter((t) => !usedTileIds.includes(t.id));
            // Piocher de nouvelles tuiles
            const tilesToDraw = Math.min(7 - player.rack.length, this.tileBag.length);
            if (tilesToDraw > 0) {
                const { drawnTiles, newBag } = drawTiles(this.tileBag, tilesToDraw);
                player.rack.push(...drawnTiles);
                this.tileBag = newBag;
            }
        }
        // TODO: Calculer et ajouter le score
        // Passer au joueur suivant
        this._nextPlayer();
    }
    _nextPlayer() {
        // Désactiver le joueur actuel
        const currentPlayer = this.players[this.currentPlayerIndex];
        if (currentPlayer) {
            currentPlayer.isActive = false;
        }
        // Passer au suivant
        this.currentPlayerIndex = (this.currentPlayerIndex + 1) % this.players.length;
        // Activer le nouveau joueur
        const nextPlayer = this.players[this.currentPlayerIndex];
        if (nextPlayer) {
            nextPlayer.isActive = true;
        }
        this.turnNumber++;
    }
    /**
     * Ajoute un joueur avec un chevalet vide (sera rempli au démarrage)
     */
    addPlayer(player) {
        if (this.players.length >= this.maxPlayers) {
            return false;
        }
        if (this.hasPlayer(player.id)) {
            return false;
        }
        // Convertir en ScrabblePlayer avec un chevalet vide
        const scrabblePlayer = {
            ...player,
            rack: []
        };
        this.players.push(scrabblePlayer);
        return true;
    }
}
//# sourceMappingURL=ScrabbleClassic.js.map