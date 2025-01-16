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
    public class PrivateChatHub(IChatMessageRepository _chatMessageRepository, IUserRepository _userRepository, MessagePersistenceService _messagePersistenceService) : Hub
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
                    m.CreatedAt,
                    m.IsRead
                })
                .ToListAsync();

            var recentChats = messages
                .GroupBy(m =>
                {
                    var otherUserId = m.ReceiverId == userId ? m.SenderId : m.ReceiverId;
                    return otherUserId;
                })
                .Select(group => new
                {
                    UserId = group.Key,
                    UserName = group.FirstOrDefault()?.ReceiverId == userId
                        ? group.FirstOrDefault()?.SenderName
                        : group.FirstOrDefault()?.ReceiverName,
                    LastMessage = group.OrderByDescending(m => m.CreatedAt).FirstOrDefault()?.Message,
                    LastMessageDate = group.Max(m => m.CreatedAt),
                    UnreadCount = group.Count(m => m.ReceiverId == userId && !m.IsRead)
                })
                .OrderByDescending(c => c.LastMessageDate)
                .ToList();

            var messagesJson = JsonSerializer.Serialize(recentChats, options: GetJsonSerializerOptions());

            Log.Information($"Usuário {userId} recebeu {recentChats.Count} conversas recentes.");

            await Clients.Caller.SendAsync("ReceiveRecentChats", messagesJson);
        }

        public async Task MarkMessagesAsRead(string senderUserId)
        {
            var receiverUserId = GetUserId();
            var messages = await _chatMessageRepository.GetTrackedEntities()
                .Where(m => m.Sender.Id == senderUserId && m.Receiver.Id == receiverUserId && !m.IsRead)
                .ToListAsync();

            Log.Information($"Usuário {receiverUserId} leu {messages.Count} de {senderUserId}");

            foreach (var message in messages)
            {
                message.IsRead = true;
            }

            await _chatMessageRepository.SaveChangesAsync();
        }

        public async Task SendImage(string receiverUserId, string imageBase64, string fileName)
        {
            var senderUserId = GetUserId();
            var senderUserName = Context.User?.Identity?.Name ?? "Desconhecido";

            Log.Information($"Usuário {senderUserId} enviou uma imagem para {receiverUserId}.");

            var imageBytes = Convert.FromBase64String(imageBase64);
            var imageStream = new MemoryStream(imageBytes);
            var s3Service = new S3Service();
            var imageUrl = await s3Service.UploadFileAsync($"images/{fileName}{Guid.NewGuid()}{Guid.NewGuid()}", imageStream, "image/jpeg");

            await _messagePersistenceService.PersistMessageAsync(senderUserId, receiverUserId, imageUrl, DateTime.UtcNow);
            await _messagePersistenceService.SendMessageAsync(senderUserId, senderUserName, receiverUserId, imageUrl);

            //Task.Run(() =>
            //{
            //    var jobId = BackgroundJob.Enqueue(() => _messagePersistenceService.PersistMessageAsync(senderUserId, receiverUserId, imageUrl, DateTime.UtcNow));
            //    BackgroundJob.ContinueJobWith(jobId, () => _messagePersistenceService.SendMessageAsync(senderUserId, senderUserName, receiverUserId, imageUrl));
            //});
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
                .Take(1000)
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

            await _messagePersistenceService.PersistMessageAsync(senderUserId, receiverUserId, message, DateTime.UtcNow);
            await _messagePersistenceService.SendMessageAsync(senderUserId, senderUserName, receiverUserId, message);

            //Task.Run(() =>
            //{
            //    var jobId = BackgroundJob.Enqueue(() => _messagePersistenceService.PersistMessageAsync(senderUserId, receiverUserId, message, DateTime.UtcNow));
            //    BackgroundJob.ContinueJobWith(jobId, () => _messagePersistenceService.SendMessageAsync(senderUserId, senderUserName, receiverUserId, message));
            //});
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
                IsRead = false
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