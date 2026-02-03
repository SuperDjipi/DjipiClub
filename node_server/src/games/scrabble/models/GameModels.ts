import type { Player } from '../../../models/games/IGame.js';
import { GameStatus } from '../../../models/games/IGame.js';
// Re-export GameStatus et Player depuis IGame pour la rétrocompatibilité
export { GameStatus };
export type { Player };

export interface BoardPosition {
    row: number;
    col: number;
}

// Équivalent de la data class Tile
export interface Tile {
    id: string;
    letter: string; // En TypeScript, un 'char' est un 'string' de longueur 1
    points: number;
    isJoker: boolean;
    assignedLetter?: string | null;
}

// Équivalent de la data class PlacedTile
export interface PlacedTile {
    tile: Tile;
    boardPosition: BoardPosition;
}

// Profil joueur
export interface UserProfile {
    id: string;
    name: string;
    hashedPassword: string;
}

// Joueur Scrabble avec chevalet (étend l'interface générique Player)
export interface ScrabblePlayer extends Player {
    rack: Tile[];
}

// Équivalent de la data class BoardCell et Board
export interface BoardCell {
    boardPosition: BoardPosition;
    bonus: string; // Ex: "LETTER_X2", "CENTER", "NONE"
    tile: Tile | null; // Le type 'Tile' ou 'null'
    isLocked?: boolean; // Indique si la tuile est verrouillée (définitivement posée)
}

export type Board = BoardCell[][]; // Un tableau de tableaux de BoardCell

// Équivalent de la data class Move (le timestamp sera géré par Date.now())
export interface Move {
    playerId: string;
    tiles: PlacedTile[];
    score: number;
    timestamp: number;
}

// Équivalent de la data class FoundWord (très utile pour la logique)
export enum Direction {
    HORIZONTAL = "HORIZONTAL",
    VERTICAL = "VERTICAL",
}

export interface FoundWord {
    text: string;
    direction: Direction;
    tiles: { tile: Tile, boardPosition: BoardPosition }[];
    start: BoardPosition;
}


// --- La pièce maîtresse : l'équivalent de GameState ---

export interface GameState {
    id: string;
    hostId: string;
    board: Board;
    players: ScrabblePlayer[];
    tileBag: Tile[];
    status: GameStatus;
    placedPositions: BoardPosition[];
    turnNumber: number;
    currentPlayerIndex: number;
    forceEndGame: number;
    // NOTE : currentPlayerRack n'est pas envoyé dans le GameState global
    // pour ne pas révéler le chevalet d'un joueur aux autres.
    // On construira un GameState spécifique pour chaque joueur.

    // Ces champs sont des états de l'UI Android et n'ont pas leur place ici.
    // Le serveur ne s'occupe que de l'état canonique du jeu.
    // La logique de validation sera faite au moment du traitement du coup.
    /*
    moves: Move[];
    foundWords: FoundWord[];
    currentMoveScore: number;
    isPlacementValid: boolean;
    areWordsValid: boolean;
    isMoveConnected: boolean;
    isCurrentMoveValid: boolean;
    moveError: string | null;
    */
}
