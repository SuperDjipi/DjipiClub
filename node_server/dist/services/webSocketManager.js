import WebSocket from 'ws';
import { URL } from 'url';
import { games, connections, initGameConnections } from '../index.js';
import { broadcastGameState } from '../index.js';
import { GameFactory } from '../games/GameFactory.js';
export function handleNewConnection(ws, req) {
    // On parse l'URL pour extraire le gameId et le playerId
    const requestUrl = new URL(req.url, `http://${req.headers.host}`);
    const gameId = requestUrl.pathname.split('/').pop()?.split('?')[0]; // Extrait l'ID de la partie de l'URL
    const playerId = requestUrl.searchParams.get('playerId'); // Extrait l'ID du joueur des paramètres de l'URL
    // Sécurité : on vérifie que les informations sont valides
    if (!gameId || !playerId || !games.has(gameId)) {
        console.log(`❌ Tentative de connexion invalide: gameId=${gameId}, playerId=${playerId}`);
        ws.close();
        return;
    }
    initGameConnections(gameId);
    const gameConnections = connections.get(gameId);
    // On associe l'instance WebSocket au joueur
    gameConnections.set(playerId, ws);
    console.log(`Joueur ${playerId} vient de se connecter à la partie ${gameId}.`);
    // --- ENVOI DE L'ÉTAT INITIAL ---
    const game = games.get(gameId);
    const eventHandler = GameFactory.getEventHandler(game.type);
    const welcomeEvent = eventHandler.createStateUpdateEvent(game, playerId);
    ws.send(JSON.stringify(welcomeEvent));
    console.log(`Envoyé l'état initial personnalisé pour ${playerId}.`);
    /**
     * Ce bloc est exécuté à chaque fois qu'un message est reçu de ce client spécifique.
     */
    ws.on('message', (message) => {
        try {
            const event = JSON.parse(message.toString());
            const currentGame = games.get(gameId);
            if (!currentGame) {
                console.warn(`Partie ${gameId} non trouvée`);
                return;
            }
            // Récupérer le handler approprié pour ce type de jeu
            const handler = GameFactory.getEventHandler(currentGame.type);
            // Déléguer le traitement de l'événement au handler
            const result = handler.handleEvent(currentGame, playerId, event);
            if (result.success) {
                // Mettre à jour l'état en mémoire
                if (result.updatedGame) {
                    games.set(gameId, result.updatedGame);
                }
                // Diffuser le nouvel état si nécessaire
                if (result.shouldBroadcast && result.updatedGame) {
                    broadcastGameState(gameId, result.updatedGame);
                }
                // Nettoyer la partie si elle est terminée
                if (result.isGameOver) {
                    setTimeout(() => {
                        games.delete(gameId);
                        connections.delete(gameId);
                        console.log(`🧹 Partie ${gameId} retirée de la mémoire`);
                    }, 60 * 60 * 1000); // 1 heure
                }
            }
            else {
                // Envoyer une erreur au client
                console.log(`❌ ${result.error}`);
                const errorEvent = handler.createErrorEvent(result.error || "Une erreur est survenue");
                ws.send(JSON.stringify(errorEvent));
            }
        }
        catch (error) {
            console.error("Erreur lors du traitement du message:", error);
        }
    });
    /**
     * Ce bloc est exécuté lorsque le client ferme sa connexion.
     */
    ws.on('close', () => {
        console.log(`👋 Joueur ${playerId} déconnecté.`);
        gameConnections.delete(playerId); // On le retire de la liste des connexions actives.
    });
}
//# sourceMappingURL=webSocketManager.js.map