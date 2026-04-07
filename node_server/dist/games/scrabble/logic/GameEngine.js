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
// On importe les fonctions utilitaires et les modules de logique spécifiques.
import { createNewBoard } from '../models/BoardModels.js';
import { isPlacementValid, isMoveConnected } from './MoveValidator.js';
import { findAllWordsFormedByMove } from './WordFinder.js';
import { isWordValid } from './Dictionary.js';
import { calculateTotalScore } from './ScoreCalculator.js';
import { drawTiles, returnTilesToBag } from './TileBag.js';
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
export function processPlayMove(currentGame, placedTiles) {
    const placedPositions = placedTiles.map(p => p.boardPosition);
    const originalBoard = currentGame.board;
    // --- Étape 1 : Création du plateau temporaire ---
    // On crée une nouvelle version du plateau qui inclut les tuiles que le joueur vient de poser.
    // C'est sur ce plateau "potentiel" que toutes les validations seront effectuées.
    const newBoard = createNewBoard(originalBoard, placedTiles);
    // --- Étape 2 : Validation complète du coup ---
    // On enchaîne toutes les règles de validation du Scrabble.
    const foundWords = findAllWordsFormedByMove(newBoard, placedTiles);
    const placementIsValid = isPlacementValid(originalBoard, placedPositions);
    const connectedIsValid = isMoveConnected(originalBoard, placedPositions, currentGame.turnNumber);
    const allWordsInDico = foundWords.size > 0 && Array.from(foundWords).every(word => isWordValid(word.text));
    // Le coup n'est valide que si toutes les conditions sont remplies.
    const isMoveFullyValid = placementIsValid && connectedIsValid && allWordsInDico;
    console.log(`MOTEUR DE JEU - VALIDATION: Placement=${placementIsValid}, Connexion=${connectedIsValid}, Dico=${allWordsInDico} -> Final=${isMoveFullyValid}`);
    // Si une seule règle n'est pas respectée, on rejette le coup en retournant `null`.
    if (!isMoveFullyValid) {
        return null;
    }
    // --- Étape 3 : Mise à jour de l'état du jeu (si le coup est valide) ---
    // Si on arrive ici, le coup est accepté et on calcule le nouvel état officiel de la partie.
    // a) Calcul du score et mise à jour du joueur
    const score = calculateTotalScore(foundWords, newBoard, placedPositions);
    const currentPlayerId = currentGame.players[currentGame.currentPlayerIndex].id;
    const updatedPlayers = currentGame.players.map(player => {
        if (player.id === currentPlayerId) {
            // On retourne une nouvelle copie du joueur avec son score mis à jour.
            return { ...player, score: player.score + score };
        }
        return player;
    });
    // b) Verrouillage des tuiles sur le plateau
    // On crée une copie du nouveau plateau et on marque les tuiles qui viennent d'être posées
    // comme étant "verrouillées" (`isLocked = true`).
    const lockedBoard = JSON.parse(JSON.stringify(newBoard)); // Copie profonde pour éviter les mutations
    placedPositions.forEach(pos => {
        if (lockedBoard[pos.row]?.[pos.col]?.tile) { // La vérification `?` est une sécurité
            lockedBoard[pos.row][pos.col].isLocked = true;
        }
    });
    // c) Pioche de nouvelles tuiles pour le joueur
    let currentTileBag = currentGame.tileBag;
    const { drawnTiles, newBag } = drawTiles(currentTileBag, placedTiles.length);
    currentTileBag = newBag; // La pioche est mise à jour.
    // Mise à jour du chevalet du joueur : on retire les tuiles jouées et on ajoute les nouvelles.
    const finalPlayers = updatedPlayers.map(player => {
        if (player.id === currentPlayerId) {
            const playedTileIds = new Set(placedTiles.map(p => p.tile.id));
            const remainingRack = player.rack.filter(t => !playedTileIds.has(t.id));
            const newRack = [...remainingRack, ...drawnTiles];
            return { ...player, rack: newRack };
        }
        return player;
    });
    // d) Passage au joueur suivant
    // L'opérateur modulo (%) garantit que l'index revient à 0 après le dernier joueur.
    const nextPlayerIndex = (currentGame.currentPlayerIndex + 1) % currentGame.players.length;
    // --- Étape 4 : Assemblage final du nouvel état ---
    // On combine toutes les nouvelles informations pour créer le `GameState` final.
    const nextGameState = {
        ...currentGame, // On garde les propriétés non modifiées (comme l'ID)
        board: lockedBoard,
        players: finalPlayers,
        tileBag: currentTileBag,
        placedPositions: placedPositions,
        turnNumber: currentGame.turnNumber + 1,
        currentPlayerIndex: nextPlayerIndex,
        forceEndGame: 0
    };
    // On retourne le nouvel état de jeu. Le contrôleur (`index.ts`) se chargera de le sauvegarder
    // et de le diffuser aux clients.
    return nextGameState;
}
export function processExchangeTiles(game, player, tilesToExchange) {
    // 1. VALIDATION CÔTÉ SERVEUR (Le point crucial)
    if (game.tileBag.length < tilesToExchange.length) {
        // Le client a essayé d'échanger plus de tuiles qu'il n'y en a de disponibles.
        // On pourrait renvoyer une erreur, ou simplement ignorer l'échange et passer le tour.
        // Pour être robuste, on ignore et on passe juste le tour.
        console.warn(`Tentative d'échange invalide par ${player.name}.`);
        // Simplement passer le tour
        game.placedPositions = []; // Pas de lettres posées
        game.currentPlayerIndex = (game.currentPlayerIndex + 1) % game.players.length;
        game.turnNumber++;
        game.forceEndGame;
        return game;
    }
    // On crée un Set d'IDs à partir des tuiles reçues pour faciliter la recherche
    const tileIdsToExchange = new Set(tilesToExchange.map((t) => t.id));
    // 2. LOGIQUE D'ÉCHANGE
    // Séparer les tuiles à garder et celles à échanger
    const tilesToKeep = player.rack.filter((t) => !tileIdsToExchange.has(t.id));
    const tilesToReturn = player.rack.filter((t) => tileIdsToExchange.has(t.id));
    // console.log(`🔄 ${player.name} laisse les tuiles : ${tilesToKeep.map(t => t.letter).join(", ")}`);
    // console.log(`🔄 ${player.name} échange les tuiles : ${tilesToReturn.map(t => t.letter).join(", ")}`);
    // 3. PIOCHER D'ABORD : Piocher le même nombre de nouvelles tuiles depuis la pioche actuelle.
    const { drawnTiles, newBag: bagAfterDrawing } = drawTiles(game.tileBag, tilesToReturn.length);
    // 4. REMETTRE ENSUITE : Ajouter les tuiles écartées à la pioche qui vient d'être utilisée.
    const finalBag = returnTilesToBag(bagAfterDrawing, tilesToReturn);
    // 5. Mettre à jour le chevalet du joueur
    player.rack = tilesToKeep.concat(drawnTiles);
    // 6. Mettre à jour l'état principal du jeu
    game.tileBag = finalBag;
    game.placedPositions = []; // Pas de lettres posées
    game.currentPlayerIndex = (game.currentPlayerIndex + 1) % game.players.length;
    game.turnNumber++;
    game.forceEndGame = 0;
    console.log(`🔄 ${player.name} a échangé ${tilesToReturn.length} tuile(s).`);
    return game;
}
//# sourceMappingURL=GameEngine.js.map