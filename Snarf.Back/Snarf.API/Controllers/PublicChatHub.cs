using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Serilog;
using Snarf.Domain.Base;
using Snarf.Domain.Entities;
using Snarf.Infrastructure.Repository;
using Snarf.Utils;
using System.Collections.Concurrent;

namespace Snarf.API.Controllers
{
    public class PublicChatHub(IPublicChatMessageRepository _publicChatMessageRepository, IUserRepository _userRepository) : Hub
    {
        private static readonly ConcurrentDictionary<string, User> _users = new();

        private string GetUserId()
        {
            return Context.User?.GetUserId() ?? throw new ArgumentNullException("O token não possui ID de usuário");
        }

        private string GetUserName()
        {
            return Context.User?.GetUserName() ?? throw new ArgumentNullException("O token não possui nome de usuário");
        }

        public async Task GetPreviousMessages()
        {
            var previousMessages = await _publicChatMessageRepository
                .GetEntities()
                .OrderByDescending(m => m.CreatedAt)
                .Take(1000)
                .OrderBy(m => m.CreatedAt)
                .Select(x => new
                {
                    x.Id,
                    SenderId = x.Sender.Id,
                    SenderName = x.Sender.Name,
                    SenderImage = x.Sender.ImageUrl,
                    SenderLatitude = x.Sender.LastLatitude,
                    SenderLongitude = x.Sender.LastLongitude,
                    x.Message,
                    x.CreatedAt
                })
                .ToListAsync();

            foreach (var message in previousMessages)
            {
                await Clients.Caller.SendAsync("ReceiveMessage", message.Id, message.CreatedAt.ToString("yyyy-MM-ddTHH:mm:ss.fffZ"), message.SenderId, message.SenderName, message.Message, message.SenderImage, message.SenderLatitude, message.SenderLongitude);
            }
        }

        public async Task SendMessage(string text)
        {
            var userId = GetUserId();
            Log.Information($"Mensagem recebida do usuário {userId}: {text}");

            if (!_users.TryGetValue(userId, out var user))
            {
                user = await _userRepository.GetEntities()
                    .Where(x => x.Id == userId)
                    .FirstOrDefaultAsync();

                if (user != null)
                {
                    _users[userId] = user;
                }
                else
                {
                    throw new Exception($"Usuário não encontrado para {userId}");
                }
            }

            var message = new PublicChatMessage
            {
                SenderId = userId,
                Message = text,
            };

            await _publicChatMessageRepository.InsertAsync(message);
            await _publicChatMessageRepository.SaveChangesAsync();

            await Clients.All.SendAsync("ReceiveMessage", message.Id, DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ"), GetUserId(), GetUserName(), text, _users[userId].ImageUrl, _users[userId].LastLatitude, _users[userId].LastLongitude);
        }

        public async Task DeleteMessage(Guid messageId)
        {
            var userId = GetUserId();

            var message = await _publicChatMessageRepository
                .GetTrackedEntities()
                .FirstOrDefaultAsync(m => m.Id == messageId)
                ?? throw new Exception("Mensagem não encontrada.");

            if (message.SenderId != userId)
                throw new Exception("Você não pode excluir mensagens de outro usuário.");

            message.Message = "Mensagem excluída";

            await _publicChatMessageRepository.SaveChangesAsync();
            Log.Information($"Mensagem {message.Id} do usuário {userId} marcada como excluída.");

            await Clients.All.SendAsync(
                "ReceiveMessageDeleted",
                message.Id,
                userId,
                "Mensagem excluída"
            );
        }

        public override async Task OnConnectedAsync()
        {
            var userId = GetUserId();
            Log.Information($"Usuário {userId} conectado ao chat público");

            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var userId = GetUserId();
            Log.Information($"Usuário {userId} desconectado do chat público");

            await base.OnDisconnectedAsync(exception);
        }
    }
}