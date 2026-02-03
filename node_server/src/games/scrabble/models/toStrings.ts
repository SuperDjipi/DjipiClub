// Fichier: src/models/toStrings.ts
    import type { GameState } from './GameModels.js';

    export function gameStateToString(state: GameState): string {
        const builder: string[] = [];

        // ID de la partie
        builder.push(`--- GAME STATE ---`);
        builder.push(`ID: ${state.id}, Host: ${state.hostId}, Turn: ${state.turnNumber}, Status: ${state.status}\n`);

        // Plateau de jeu
        builder.push("--- BOARD ---");
        state.board.forEach(row => {
            const rowString = row.map(cell => {
                // Utilise la lettre assignée au joker si elle existe, sinon la lettre de base
                return cell.tile?.assignedLetter || cell.tile?.letter || '_';
            }).join(' ');
            builder.push(rowString);
        });
        builder.push(''); // Ligne vide

        // Liste des joueurs
        builder.push("--- PLAYERS ---");
        state.players.forEach((player, index) => {
            const turnIndicator = (index === state.currentPlayerIndex) ? "*" : "";
            builder.push(`- ID: ${player.id}${turnIndicator}, Name: ${player.name}, Score: ${player.score}`);
        });
        builder.push("------------------\n");

        return builder.join('\n');
    }