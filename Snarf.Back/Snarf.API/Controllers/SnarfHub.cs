using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Serilog;
using Snarf.DTO;
using Snarf.Infrastructure.Repository;
using Snarf.Utils;
using System.Text.Json;

namespace Snarf.API.Controllers
{
    public class SnarfHub(IUserRepository _userRepository) : Hub
    {
        public async Task SendMessage(string jsonMessage)
        {
            var message = SignalRMessage.Deserialize(jsonMessage);

            switch (message.Type)
            {
                case "UpdateLocation":
                    await HandleUpdateLocation(message.Data);
                    break;
                default:
                    Log.Warning($"Tipo de mensagem não reconhecido: {message.Type}");
                    break;
            }
        }

        private async Task HandleUpdateLocation(JsonElement data)
        {
            var userId = GetUserId();
            var location = JsonSerializer.Deserialize<LocationModel>(data.ToString());

            var user = await _userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == userId);

            if (user == null) return;

            user.LastActivity = DateTime.UtcNow;
            user.LastLatitude = location.Latitude;
            user.LastLongitude = location.Longitude;
            await _userRepository.SaveChangesAsync();

            Log.Information($"Localização atualizada: {userId} - ({location.Latitude}, {location.Longitude})");

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.ReceiveLocation, new
            {
                userId,
                location.Latitude,
                location.Longitude,
                user.Name,
                user.ImageUrl
            });

            await Clients.Others.SendAsync("ReceiveMessage", jsonResponse);
        }

        public override async Task OnConnectedAsync()
        {
            var userId = GetUserId();

            Log.Information($"Usuário conectado: {userId}");

            await base.OnConnectedAsync();
        }

        public override async Task OnDisconnectedAsync(Exception? exception)
        {
            var userId = GetUserId();
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