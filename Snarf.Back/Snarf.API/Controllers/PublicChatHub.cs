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
                    SenderId = x.Sender.Id,
                    SenderName = x.Sender.Name,
                    SenderImage = x.Sender.ImageUrl,
                    x.Message,
                    x.CreatedAt
                })
                .ToListAsync();

            foreach (var message in previousMessages)
            {
                await Clients.Caller.SendAsync("ReceiveMessage", message.CreatedAt, message.SenderId, message.SenderName, message.Message, message.SenderImage);
            }
        }

        public async Task SendMessage(string message)
        {
            var userId = GetUserId();
            Log.Information($"Mensagem recebida do usuário {userId}: {message}");

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

            var publicChatMessage = new PublicChatMessage
            {
                SenderId = userId,
                Message = message,
            };

            await _publicChatMessageRepository.InsertAsync(publicChatMessage);
            await _publicChatMessageRepository.SaveChangesAsync();

            await Clients.All.SendAsync("ReceiveMessage", DateTime.UtcNow, GetUserId(), GetUserName(), message, _users[userId].ImageUrl);
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