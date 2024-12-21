using Microsoft.AspNetCore.SignalR;
using Snarf.Utils;
using System;
using System.Collections.Concurrent;
using System.Threading.Tasks;

namespace Snarf.API.Controllers
{
    public class PrivateChatHub : Hub
    {
        private static readonly ConcurrentDictionary<string, string> UserConnections = new();

        private string GetUserId()
        {
            return Context.User?.GetUserId() ?? throw new ArgumentNullException("O token não possui ID de usuário");
        }

        public override async Task OnConnectedAsync()
        {
            var userId = GetUserId();
            UserConnections[userId] = Context.ConnectionId;

            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var userId = GetUserId();
            UserConnections.TryRemove(userId, out _);

            await base.OnDisconnectedAsync(exception);
        }

        public async Task SendPrivateMessage(string targetUserId, string message)
        {
            var senderUserId = GetUserId();

            if (UserConnections.TryGetValue(targetUserId, out var targetConnectionId))
            {
                await Clients.Client(targetConnectionId).SendAsync("ReceivePrivateMessage", senderUserId, message);
            }
            else
            {
                throw new InvalidOperationException("Usuário destinatário não está conectado.");
            }
        }
    }
}