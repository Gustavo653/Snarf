using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Serilog;
using Snarf.Domain.Entities;
using Snarf.DTO;
using Snarf.Infrastructure.Repository;
using Snarf.Utils;
using System.Collections.Concurrent;
using System.Text.Json;

namespace Snarf.API.Controllers
{
    public class SnarfHub(
        IUserRepository _userRepository,
        IPublicChatMessageRepository _publicChatMessageRepository,
        IBlockedUserRepository _blockedUserRepository) : Hub
    {
        private static ConcurrentDictionary<string, List<string>> _userConnections = new();

        public async Task SendMessage(string jsonMessage)
        {
            var message = SignalRMessage.Deserialize(jsonMessage);

            switch (message.Type)
            {
                case "UpdateLocation":
                    await HandleUpdateLocation(message.Data);
                    break;
                case "SendMessage":
                    await HandleSendMessage(message.Data);
                    break;
                case "DeleteMessage":
                    await HandleDeleteMessage(message.Data);
                    break;
                case "GetPreviousMessages":
                    await HandleGetPreviousMessages();
                    break;
                default:
                    Log.Warning($"Evento desconhecido recebido: {message.Type}");
                    break;
            }
        }

        private async Task HandleUpdateLocation(JsonElement data)
        {
            var userId = GetUserId();
            var location = JsonSerializer.Deserialize<LocationModel>(data.ToString());

            var user = await _userRepository.GetTrackedEntities()
                .Where(x => x.Id == userId)
                .FirstOrDefaultAsync();

            if (user == null) return;

            user.LastActivity = DateTime.UtcNow;
            user.LastLatitude = location.Latitude;
            user.LastLongitude = location.Longitude;
            await _userRepository.SaveChangesAsync();

            Log.Information($"Localização atualizada: {userId} - ({location.Latitude}, {location.Longitude})");

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.ReceiveLocation, new
            {
                userId,
                Latitude = location.Latitude,
                Longitude = location.Longitude,
                user.Name,
                user.ImageUrl
            });

            await Clients.Others.SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandleSendMessage(JsonElement data)
        {
            var userId = GetUserId();
            var text = data.GetProperty("Message").GetString();
            if (string.IsNullOrWhiteSpace(text)) return;

            var user = await _userRepository.GetTrackedEntities()
                .FirstOrDefaultAsync(x => x.Id == userId);

            if (user == null) return;

            var message = new PublicChatMessage
            {
                SenderId = userId,
                Message = text
            };

            await _publicChatMessageRepository.InsertAsync(message);
            await _publicChatMessageRepository.SaveChangesAsync();

            var blockedUsers = await _blockedUserRepository
                .GetEntities()
                .Where(b => b.Blocked.Id == userId)
                .Select(b => b.Blocker.Id)
                .ToListAsync();

            var blockedConnectionIds = new List<string>();

            foreach (var blockedUserId in blockedUsers)
            {
                if (_userConnections.TryGetValue(blockedUserId, out var connections))
                {
                    blockedConnectionIds.AddRange(connections);
                }
            }

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.ReceiveMessage, new
            {
                message.Id,
                CreatedAt = DateTime.UtcNow,
                UserId = userId,
                UserName = user.Name,
                UserImage = user.ImageUrl,
                Latitude = user.LastLatitude,
                Longitude = user.LastLongitude,
                Message = text
            });

            await Clients.AllExcept(blockedConnectionIds).SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandleDeleteMessage(JsonElement data)
        {
            var userId = GetUserId();
            var messageId = data.GetProperty("MessageId").GetString();

            var message = await _publicChatMessageRepository
                .GetTrackedEntities()
                .FirstOrDefaultAsync(m => m.Id == Guid.Parse(messageId))
                ?? throw new Exception("Mensagem não encontrada.");

            if (message.SenderId != userId)
                throw new Exception("Você não pode excluir mensagens de outro usuário.");

            message.Message = "Mensagem excluída";

            await _publicChatMessageRepository.SaveChangesAsync();
            Log.Information($"Mensagem {message.Id} do usuário {userId} marcada como excluída.");

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.ReceiveMessageDeleted, new
            {
                MessageId = message.Id,
                Message = "Mensagem excluída"
            });

            await Clients.All.SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandleGetPreviousMessages()
        {
            var userId = GetUserId();
            var previousMessages = await _publicChatMessageRepository
                .GetEntities()
                .Where(x => !x.Sender.BlockedBy.Select(x => x.Blocker.Id).Contains(userId))
                .OrderByDescending(m => m.CreatedAt)
                .Take(1000)
                .OrderBy(m => m.CreatedAt)
                .Select(x => new
                {
                    x.Id,
                    CreatedAt = x.CreatedAt.ToUniversalTime(),
                    UserId = x.Sender.Id,
                    UserName = x.Sender.Name,
                    UserImage = x.Sender.ImageUrl,
                    Latitude = x.Sender.LastLatitude,
                    Longitude = x.Sender.LastLongitude,
                    x.Message
                })
                .ToListAsync();

            foreach (var message in previousMessages)
            {
                var jsonResponse = SignalRMessage.Serialize(SignalREventType.ReceiveMessage, message);
                await Clients.Caller.SendAsync("ReceiveMessage", jsonResponse);
            }
        }

        public override async Task OnConnectedAsync()
        {
            var userId = GetUserId();
            Log.Information($"Usuário {userId} conectado");

            if (_userConnections.TryGetValue(userId, out var connections))
            {
                connections.Add(Context.ConnectionId);
            }
            else
            {
                _userConnections[userId] = new List<string> { Context.ConnectionId };
            }

            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var userId = GetUserId();
            Log.Information($"Usuário {userId} desconectado");

            if (_userConnections.TryGetValue(userId, out var connections))
            {
                connections.Remove(Context.ConnectionId);
                if (connections.Count == 0)
                {
                    _userConnections.TryRemove(userId, out _);
                }
            }

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.UserDisconnected, new { userId });
            await Clients.Others.SendAsync("ReceiveMessage", jsonResponse);

            await base.OnDisconnectedAsync(exception);
        }

        private string GetUserId()
        {
            return Context.User?.GetUserId() ?? throw new ArgumentNullException("O token não possui ID de usuário");
        }

        private class LocationModel
        {
            public double Latitude { get; set; }
            public double Longitude { get; set; }
        }
    }
}