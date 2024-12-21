using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Serilog;
using Snarf.Domain.Entities;
using Snarf.Infrastructure.Repository;
using Snarf.Utils;
using System.Collections.Concurrent;
using System.Text.Json;

namespace Snarf.API.Controllers
{
    public class PrivateChatHub(IChatMessageRepository _chatMessageRepository, IUserRepository _userRepository) : Hub
    {
        private static readonly ConcurrentDictionary<string, string> UserConnections = new();

        private string GetUserId()
        {
            return Context.User?.GetUserId() ?? throw new ArgumentNullException("O token não possui ID de usuário");
        }

        public override async Task OnConnectedAsync()
        {
            var userId = GetUserId();

            Log.Information($"Usuário {userId} conectado com ConnectionId {Context.ConnectionId}");

            UserConnections[userId] = Context.ConnectionId;

            await base.OnConnectedAsync();
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
                    SenderName = x.Sender.Name,
                    ReceiverId = x.Receiver.Id,
                    ReceiverName = x.Receiver.Name,
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
            UserConnections.TryRemove(userId, out _);

            await base.OnDisconnectedAsync(exception);
        }

        public async Task SendPrivateMessage(string receiverUserId, string message)
        {
            var senderUserId = GetUserId();

            var sender = await _userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == senderUserId) ?? throw new Exception($"Usuário com ID {senderUserId} não existe");
            var receiver = await _userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == receiverUserId) ?? throw new Exception($"Usuário com ID {receiverUserId} não existe");

            var chatMessage = new ChatMessage
            {
                Sender = sender,
                Receiver = receiver,
                Message = message
            };

            await _chatMessageRepository.InsertAsync(chatMessage);
            await _chatMessageRepository.SaveChangesAsync();

            if (UserConnections.TryGetValue(receiverUserId, out var targetConnectionId))
            {
                await Clients.Client(targetConnectionId).SendAsync("ReceivePrivateMessage", sender.Name, message);
            }
            else
            {
                Log.Warning($"Usuário com id {receiverUserId} está offline");
            }
        }
    }
}
