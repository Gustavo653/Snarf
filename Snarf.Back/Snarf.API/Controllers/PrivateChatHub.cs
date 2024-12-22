using Hangfire;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Serilog;
using Snarf.Domain.Entities;
using Snarf.Infrastructure.Repository;
using Snarf.Service;
using Snarf.Utils;
using System.Text.Json;

namespace Snarf.API.Controllers
{
    public class PrivateChatHub(IChatMessageRepository _chatMessageRepository, MessagePersistenceService _messagePersistenceService) : Hub
    {
        private static JsonSerializerOptions GetJsonSerializerOptions()
        {
            return new JsonSerializerOptions { Converters = { new DateTimeConverterToTimeZone("America/Sao_Paulo") } };
        }

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

            var recentChats = messages
                .GroupBy(m =>
                {
                    var senderId = m.SenderId;
                    var receiverId = m.ReceiverId;

                    return senderId.CompareTo(receiverId) < 0
                        ? (senderId, receiverId)
                        : (receiverId, senderId);
                })
                .Select(group => new
                {
                    UserId = group.Key.Item1,
                    UserName = group.Key.Item1 == group.First().SenderId
                        ? group.First().ReceiverName
                        : group.First().SenderName,
                    LastMessage = group.OrderByDescending(m => m.CreatedAt).FirstOrDefault()?.Message,
                    LastMessageDate = group.Max(m => m.CreatedAt)
                })
                .OrderByDescending(c => c.LastMessageDate)
                .ToList();

            var messagesJson = JsonSerializer.Serialize(recentChats, options: GetJsonSerializerOptions());

            Log.Information($"Usuário {userId} recebeu {recentChats.Count} conversas recentes.");

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

            var messagesJson = JsonSerializer.Serialize(previousMessages, options: GetJsonSerializerOptions());

            Log.Information($"Enviando {previousMessages.Count} mensagens anteriores para o usuário {userId} com o receptor {receiverUserId}");

            await Clients.Caller.SendAsync("ReceivePreviousMessages", messagesJson);
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var userId = GetUserId();

            if (exception != null)
                Log.Warning($"Erro durante desconexão de {userId}: {exception.Message}");
            else
                Log.Information($"Usuário {userId} desconectado com ConnectionId {Context.ConnectionId}");

            await base.OnDisconnectedAsync(exception);
        }

        public async Task SendPrivateMessage(string receiverUserId, string message)
        {
            var senderUserId = GetUserId();
            var senderUserName = Context.User?.Identity?.Name ?? "Desconhecido";

            Log.Information($"Usuário {senderUserId} ({senderUserName}) enviou mensagem privada para {receiverUserId}: {message}");

            await Task.Run(() =>
            {
                var jobId = BackgroundJob.Enqueue(() => _messagePersistenceService.PersistMessageAsync(senderUserId, receiverUserId, message, DateTime.UtcNow));
                BackgroundJob.ContinueJobWith(jobId, () => _messagePersistenceService.SendMessageAsync(senderUserId, senderUserName, receiverUserId, message));
            });
        }
    }

    public class MessagePersistenceService(IChatMessageRepository chatMessageRepository, IUserRepository userRepository, IHubContext<PrivateChatHub> hubContext)
    {
        public async Task PersistMessageAsync(string senderUserId, string receiverUserId, string message, DateTime dateTime)
        {
            var sender = await userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == senderUserId);
            var receiver = await userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == receiverUserId);

            if (sender == null || receiver == null)
            {
                throw new Exception("Usuário não encontrado");
            }

            var chatMessage = new ChatMessage
            {
                Sender = sender,
                Receiver = receiver,
                Message = message,
            };

            chatMessage.SetCreatedAt(dateTime);

            await chatMessageRepository.InsertAsync(chatMessage);
            await chatMessageRepository.SaveChangesAsync();
        }

        public async Task SendMessageAsync(string senderUserId, string senderUserName, string receiverUserId, string message)
        {
            await hubContext.Clients.User(receiverUserId).SendAsync("ReceivePrivateMessage", senderUserId, senderUserName, message);
        }
    }
}