import type { GameState, PlacedTile, Tile } from "./GameModels.js";

// --- Événements que le CLIENT envoie au SERVEUR ---

export interface JoinGameEvent {
    type: "JOIN_GAME";
    payload: {
        gameId: string;
        playerId: string;
    };
}
export interface StartGameEvent {
    type: "START_GAME";
}
export interface PlayMoveEvent {
    type: "PLAY_MOVE";
    payload: {
        placedTiles: PlacedTile[];
    };
}
export interface PassTurnEvent {
    type: "PASS_TURN";
}
export interface ExchangeTilesEvent {
    type: "EXCHANGE_TILES";
    payload: {
        tilesToExchange: Tile[];
    };
}
export interface RegisterProfileEvent {
    type: "REGISTER_PROFILE";
    payload: {
        name: string;
    };
}

// ... (on pourra ajouter PassTurnEvent, ShuffleEvent, etc. plus tard)

// Un type qui représente tous les événements possibles venant du client
export type ClientToServerEvent = JoinGameEvent | StartGameEvent | PlayMoveEvent | PassTurnEvent | ExchangeTilesEvent | RegisterProfileEvent;


// --- Événements que le SERVEUR envoie au CLIENT ---

export interface GameStateUpdateEvent {
    type: "GAME_STATE_UPDATE";
    payload: {
        gameState: GameState;
        // On envoie aussi le chevalet spécifique à ce joueur
        playerRack: Tile[];
    };
}

export interface ErrorEvent {
    type: "ERROR";
    payload: {
        message: string;
    };
}

// Un type qui représente tous les événements possibles venant du serveur
export type ServerToClientEvent = GameStateUpdateEvent | ErrorEvent;