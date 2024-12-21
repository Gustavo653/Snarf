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

            Task.Run(() => _backgroundJobClient.Enqueue(() => _messagePersistenceService.PersistMessageAsync(senderUserId, receiverUserId, message)));

            await Clients.User(receiverUserId).SendAsync("ReceivePrivateMessage", message);
        }
    }
}
