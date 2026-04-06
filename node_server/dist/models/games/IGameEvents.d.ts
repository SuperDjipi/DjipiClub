import type { IGame } from './IGame.js';
/**
 * Événement générique client → serveur
 */
export interface IClientEvent {
    type: string;
    payload?: any;
}
/**
 * Événement générique serveur → client
 */
export interface IServerEvent {
    type: string;
    payload?: any;
}
/**
 * Résultat du traitement d'un événement
 */
export interface EventResult {
    success: boolean;
    updatedGame?: IGame;
    error?: string;
    shouldBroadcast?: boolean;
    isGameOver?: boolean;
}
/**
 * Interface pour les gestionnaires d'événements spécifiques à chaque jeu.
 * Chaque type de jeu (Scrabble, Boggle, etc.) implémente cette interface
 * pour traiter ses propres événements.
 */
export interface IGameEventHandler {
    /**
     * Traite un événement reçu d'un client
     * @param game L'état actuel du jeu
     * @param playerId L'ID du joueur qui a envoyé l'événement
     * @param event L'événement à traiter
     * @returns Le résultat du traitement
     */
    handleEvent(game: IGame, playerId: string, event: IClientEvent): EventResult;
    /**
     * Crée un événement de mise à jour d'état pour un joueur spécifique
     * @param game L'état actuel du jeu
     * @param playerId L'ID du joueur destinataire
     * @returns L'événement personnalisé pour ce joueur
     */
    createStateUpdateEvent(game: IGame, playerId: string): IServerEvent;
    /**
     * Crée un événement d'erreur
     * @param message Le message d'erreur
     * @returns L'événement d'erreur
     */
    createErrorEvent(message: string): IServerEvent;
}
//# sourceMappingURL=IGameEvents.d.ts.map