/**
 * Ce fichier contient le "Moteur de Jeu" (Game Engine).
 *
 * Son rôle est d'encapsuler toute la logique et les règles du jeu de Scrabble.
 * Il est conçu pour être "pur", ce qui signifie qu'il ne dépend pas du réseau (WebSockets)
 * ou de l'interface utilisateur. Il ne fait que prendre des états de jeu en entrée
 * et retourner de nouveaux états de jeu en sortie.
 *
 * Cette séparation des responsabilités le rend très facile à tester et à maintenir.
 * Si une règle du jeu change, c'est le seul fichier qui doit être modifié.
 */
import type { GameState, Tile, PlacedTile, ScrabblePlayer } from '../models/GameModels.js';
/**
 * Traite un coup joué par un utilisateur ("Play Move").
 *
 * Cette fonction exécute l'intégralité de la séquence de validation et de mise à jour pour un coup.
 * Elle est la fonction la plus complexe et la plus importante du moteur de jeu.
 *
 * @param currentGame L'état actuel de la partie, avant que le coup ne soit appliqué.
 * @param placedTiles La liste des tuiles que le joueur a posées sur le plateau.
 * @returns Le nouvel état `GameState` si le coup est valide, ou `null` si le coup est invalide.
 */
export declare function processPlayMove(currentGame: GameState, placedTiles: PlacedTile[]): GameState | null;
export declare function processExchangeTiles(game: GameState, player: ScrabblePlayer, tilesToExchange: Tile[]): GameState;
//# sourceMappingURL=GameEngine.d.ts.map