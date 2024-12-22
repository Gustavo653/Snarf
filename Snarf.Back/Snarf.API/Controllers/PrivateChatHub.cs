using Hangfire;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Serilog;
using Snarf.Infrastructure.Repository;
using Snarf.Service;
using Snarf.Utils;
using System.Text.Json;

namespace Snarf.API.Controllers
{
    public class PrivateChatHub(IChatMessageRepository _chatMessageRepository, IBackgroundJobClient _backgroundJobClient, MessagePersistenceService _messagePersistenceService) : Hub
    {
        private string GetUserId()
        {
            return Context.User?.GetUserId() ?? throw new ArgumentNullException("O token não possui ID de usuário");
        }

        public override async Task OnConnectedAsync()
        {
            var userId = GetUserId();

            Log.Information($"Usuário {userId} conectado com ConnectionId {Context.ConnectionId}");

            await base.OnConnectedAsync();
        }

        public async Task GetRecentChats()
        {
            var userId = GetUserId();

            Log.Information($"Usuário {userId} solicitou a lista de conversas recentes.");

            // Carrega todas as mensagens relevantes do banco
            var messages = await _chatMessageRepository.GetEntities()
                .Where(m => m.Sender.Id == userId || m.Receiver.Id == userId)
                .Select(m => new
                {
                    SenderId = m.Sender.Id,
                    SenderName = m.Sender.Name,
                    ReceiverId = m.Receiver.Id,
                    ReceiverName = m.Receiver.Name,
                    m.Message,
                    m.CreatedAt
                })
                .ToListAsync();

            // Processa os dados em memória
            var recentChats = messages
                .GroupBy(m =>
                {
                    // Usa uma tupla para comparar os guids de maneira consistente e evitar duplicação de nomes
                    var senderId = m.SenderId;
                    var receiverId = m.ReceiverId;

                    // Ordena os guids para garantir que a chave seja única, independentemente da ordem de envio/recebimento
                    return senderId.CompareTo(receiverId) < 0
                        ? (senderId, receiverId)
                        : (receiverId, senderId);
                })
                .Select(group => new
                {
                    // A chave da tupla agora é usada para obter os ids de sender e receiver
                    UserId = group.Key.Item1, // Primeiro id da tupla (o menor)
                    UserName = group.Key.Item1 == group.First().SenderId
                        ? group.First().ReceiverName
                        : group.First().SenderName, // Nome do outro usuário
                    LastMessage = group.OrderByDescending(m => m.CreatedAt).FirstOrDefault()?.Message,
                    LastMessageDate = group.Max(m => m.CreatedAt)
                })
                .OrderByDescending(c => c.LastMessageDate) // Ordena pela data da última mensagem
                .ToList();

            var messagesJson = JsonSerializer.Serialize(recentChats, options: new JsonSerializerOptions { Converters = { new DateTimeConverterToTimeZone("America/Sao_Paulo") } });

            Log.Information($"Usuário {userId} recebeu {recentChats.Count} conversas recentes.");

            // Enviar as conversas recentes para o cliente
            await Clients.Caller.SendAsync("ReceiveRecentChats", messagesJson);
        }

        public async Task GetPreviousMessages(string receiverUserId)
        {
            var userId = GetUserId();

            Log.Information($"Usuário {userId} solicitou mensagens anteriores com o usuário {receiverUserId}");

            var previousMessages = await _chatMessageRepository.GetEntities()
                .Include(m => m.Sender)
                .Include(m => m.Receiver)
                .Where(m => (m.Sender.Id == userId && m.Receiver.Id == receiverUserId) ||
                            (m.Sender.Id == receiverUserId && m.Receiver.Id == userId))
                .Select(x => new
                {
                    x.CreatedAt,
                    SenderId = x.Sender.Id,
                    ReceiverId = x.Receiver.Id,
                    x.Message
                })
                .OrderBy(m => m.CreatedAt)
                .ToListAsync();

            var messagesJson = JsonSerializer.Serialize(previousMessages, options: new JsonSerializerOptions { Converters = { new DateTimeConverterToTimeZone("America/Sao_Paulo") } });

            Log.Information($"Enviando {previousMessages.Count} mensagens anteriores para o usuário {userId} com o receptor {receiverUserId}");

            await Clients.Caller.SendAsync("ReceivePreviousMessages", messagesJson);
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var userId = GetUserId();

            Log.Information($"Usuário {userId} desconectado com ConnectionId {Context.ConnectionId}");

            await base.OnDisconnectedAsync(exception);
        }

        public async Task SendPrivateMessage(string receiverUserId, string message)
        {
            var senderUserId = GetUserId();
            var senderUserName = Context.User?.Identity?.Name ?? "Desconhecido";  // Obter o nome do usuário a partir do contexto

            // Enfileira a persistência da mensagem em segundo plano
            Task.Run(() => _backgroundJobClient.Enqueue(() => _messagePersistenceService.PersistMessageAsync(senderUserId, receiverUserId, message, DateTime.UtcNow)));

            // Envia a mensagem para o receptor, incluindo os detalhes do remetente
            await Clients.User(receiverUserId).SendAsync("ReceivePrivateMessage", senderUserId, senderUserName, message);
        }
    }
}
