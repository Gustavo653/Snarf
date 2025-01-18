using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Serilog;
using Snarf.Domain.Entities;
using Snarf.Infrastructure.Repository;
using Snarf.Utils;

namespace Snarf.API.Controllers
{
    public class PublicChatHub(IPublicChatMessageRepository _publicChatMessageRepository, IUserRepository _userRepository) : Hub
    {
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
                    x.Message,
                    x.CreatedAt
                })
                .ToListAsync();

            foreach (var message in previousMessages)
            {
                await Clients.Caller.SendAsync("ReceiveMessage", message.CreatedAt, message.SenderId, message.SenderName, message.Message);
            }
        }

        public async Task SendMessage(string message)
        {
            var userId = GetUserId();
            Log.Information($"Mensagem recebida do usuário {userId}: {message}");

            var publicChatMessage = new PublicChatMessage
            {
                SenderId = userId,
                Message = message,
            };

            await _publicChatMessageRepository.InsertAsync(publicChatMessage);
            await _publicChatMessageRepository.SaveChangesAsync();

            await Clients.All.SendAsync("ReceiveMessage", DateTime.UtcNow, GetUserId(), GetUserName(), message);
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