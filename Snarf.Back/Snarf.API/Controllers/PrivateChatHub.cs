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
    public class PrivateChatHub(IPrivateChatMessageRepository _privateChatMessageRepository, IUserRepository _userRepository, IFavoriteChatRepository _favoriteChatRepository, MessagePersistenceService _messagePersistenceService) : Hub
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

            var messages = await _privateChatMessageRepository.GetEntities()
                .Where(m => m.Sender.Id == userId || m.Receiver.Id == userId)
                .Select(m => new
                {
                    SenderId = m.Sender.Id,
                    SenderName = m.Sender.Name,
                    SenderImage = m.Sender.ImageUrl,
                    ReceiverId = m.Receiver.Id,
                    ReceiverName = m.Receiver.Name,
                    ReceiverImage = m.Receiver.ImageUrl,
                    m.Message,
                    m.CreatedAt,
                    m.IsRead,
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
                    UserImage = group.FirstOrDefault()?.ReceiverId == userId
                        ? group.FirstOrDefault()?.SenderImage
                        : group.FirstOrDefault()?.ReceiverImage,
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
            var messages = await _privateChatMessageRepository.GetTrackedEntities()
                .Where(m => m.Sender.Id == senderUserId && m.Receiver.Id == receiverUserId && !m.IsRead)
                .ToListAsync();

            Log.Information($"Usuário {receiverUserId} leu {messages.Count} de {senderUserId}");

            foreach (var message in messages)
            {
                message.IsRead = true;
            }

            await _privateChatMessageRepository.SaveChangesAsync();
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

            var previousMessages = await _privateChatMessageRepository.GetEntities()
                .Include(m => m.Sender)
                .Include(m => m.Receiver)
                .Where(m => (m.Sender.Id == userId && m.Receiver.Id == receiverUserId) ||
                            (m.Sender.Id == receiverUserId && m.Receiver.Id == userId))
                .Select(x => new
                {
                    x.Id,
                    x.CreatedAt,
                    SenderId = x.Sender.Id,
                    ReceiverId = x.Receiver.Id,
                    x.Message
                })
                .OrderByDescending(m => m.CreatedAt)
                .Take(1000)
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

            await _messagePersistenceService.PersistMessageAsync(senderUserId, receiverUserId, message, DateTime.UtcNow);
            await _messagePersistenceService.SendMessageAsync(senderUserId, senderUserName, receiverUserId, message);

            //Task.Run(() =>
            //{
            //    var jobId = BackgroundJob.Enqueue(() => _messagePersistenceService.PersistMessageAsync(senderUserId, receiverUserId, message, DateTime.UtcNow));
            //    BackgroundJob.ContinueJobWith(jobId, () => _messagePersistenceService.SendMessageAsync(senderUserId, senderUserName, receiverUserId, message));
            //});
        }

        public async Task AddFavorite(string chatUserId)
        {
            var userId = GetUserId();

            var user = await _userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == userId);
            var chatUser = await _userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == chatUserId);

            var favorite = new FavoriteChat
            {
                User = user!,
                ChatUser = chatUser!,
            };

            await _favoriteChatRepository.InsertAsync(favorite);
            await _favoriteChatRepository.SaveChangesAsync();

            Log.Information($"Usuário {userId} favoritou o chat com {chatUserId}");
        }

        public async Task RemoveFavorite(string chatUserId)
        {
            var userId = GetUserId();
            var favorite = await _favoriteChatRepository.GetTrackedEntities()
                .FirstOrDefaultAsync(f => f.User.Id == userId && f.ChatUser.Id == chatUserId);

            if (favorite != null)
            {
                _favoriteChatRepository.Delete(favorite);
                await _favoriteChatRepository.SaveChangesAsync();
                Log.Information($"Usuário {userId} removeu o favorito do chat com {chatUserId}");
            }
        }

        public async Task GetFavorites()
        {
            var userId = GetUserId();
            var favorites = await _favoriteChatRepository.GetEntities()
                .Where(f => f.User.Id == userId)
                .Select(f => new { f.ChatUser.Id })
                .ToListAsync();

            var favoriteIdsJson = JsonSerializer.Serialize(favorites.Select(f => f.Id));
            await Clients.Caller.SendAsync("ReceiveFavorites", favoriteIdsJson);
        }

        public async Task DeleteMessage(Guid messageId)
        {
            var userId = GetUserId();

            var message = await _privateChatMessageRepository
                .GetTrackedEntities()
                .Include(x => x.Receiver)
                .Include(x => x.Sender)
                .FirstOrDefaultAsync(m => m.Id == messageId);

            if (message == null)
            {
                Log.Warning($"Mensagem {messageId} não encontrada para exclusão pelo usuário {userId}");
                throw new Exception("Mensagem não encontrada");
            }

            if (message.Sender.Id != userId && message.Receiver.Id != userId)
            {
                Log.Warning($"Usuário {userId} tentou excluir mensagem {messageId} sem permissão");
                throw new UnauthorizedAccessException("Você não tem permissão para excluir esta mensagem");
            }

            if (message.Message.StartsWith("https://"))
            {
                var s3Service = new S3Service();
                await s3Service.DeleteFileAsync(message.Message);
            }

            message.Message = "Mensagem excluída";
            await _privateChatMessageRepository.SaveChangesAsync();
            Log.Information($"Usuário {userId} excluiu a mensagem {messageId}");

            await Clients.User(message.Sender.Id).SendAsync("MessageDeleted", messageId);
            await Clients.User(message.Receiver.Id).SendAsync("MessageDeleted", messageId);
        }

        public async Task DeleteChat(string receiverUserId)
        {
            var userId = GetUserId();
            var messages = await _privateChatMessageRepository.GetTrackedEntities()
                .Include(x => x.Sender)
                .Include(x => x.Receiver)
                .Where(m => (m.Sender.Id == userId && m.Receiver.Id == receiverUserId) ||
                            (m.Sender.Id == receiverUserId && m.Receiver.Id == userId))
                .ToListAsync();
            foreach (var message in messages)
            {
                await Clients.User(message.Sender.Id).SendAsync("MessageDeleted", message.Id);
                await Clients.User(message.Receiver.Id).SendAsync("MessageDeleted", message.Id);
                if (message.Message.StartsWith("https://"))
                {
                    var s3Service = new S3Service();
                    await s3Service.DeleteFileAsync(message.Message);
                }
                else
                {
                    _privateChatMessageRepository.Delete(message);
                }
            }
            await _privateChatMessageRepository.SaveChangesAsync();
            Log.Information($"Usuário {userId} excluiu o chat com {receiverUserId}");
        }
    }

    public class MessagePersistenceService(IPrivateChatMessageRepository chatMessageRepository, IUserRepository userRepository, IHubContext<PrivateChatHub> hubContext)
    {
        public async Task PersistMessageAsync(string senderUserId, string receiverUserId, string message, DateTime dateTime)
        {
            var sender = await userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == senderUserId);
            var receiver = await userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == receiverUserId);

            if (sender == null || receiver == null)
            {
                throw new Exception("Usuário não encontrado");
            }

            var chatMessage = new PrivateChatMessage
            {
                Sender = sender,
                Receiver = receiver,
                Message = message,
                IsRead = false
            };

            chatMessage.SetCreatedAt(dateTime);

            await chatMessageRepository.InsertAsync(chatMessage);
            await chatMessageRepository.SaveChangesAsync();

            await hubContext.Clients.User(receiverUserId).SendAsync("ReceivePrivateMessage", chatMessage.Id, senderUserId, sender.Name, message);
            await hubContext.Clients.User(senderUserId).SendAsync("ReceivePrivateMessage", chatMessage.Id, senderUserId, sender.Name, message);
        }

        public async Task SendMessageAsync(string senderUserId, string senderUserName, string receiverUserId, string message)
        {
            //await hubContext.Clients.User(receiverUserId).SendAsync("ReceivePrivateMessage", senderUserId, senderUserName, message);
        }
    }
}