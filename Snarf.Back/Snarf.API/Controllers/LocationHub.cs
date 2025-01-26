using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Serilog;
using Snarf.Infrastructure.Repository;
using Snarf.Utils;

namespace Snarf.API.Controllers
{
    public class LocationHub(IUserRepository _userRepository) : Hub
    {
        public async Task UpdateLocation(double latitude, double longitude)
        {
            var userId = GetUserId();

            var user = await _userRepository.GetTrackedEntities()
                .Where(x => x.Id == userId)
                .FirstOrDefaultAsync();

            user.LastActivity = DateTime.UtcNow;
            user.LastLatitude = latitude;
            user.LastLongitude = longitude;
            await _userRepository.SaveChangesAsync();

            Log.Information($"Atualizando localização de {userId} ({user.Name}): ({latitude}, {longitude})");

            await Clients.Others.SendAsync("ReceiveLocation", userId, latitude, longitude, user.Name, user.ImageUrl);
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

            await Clients.Others.SendAsync("UserDisconnected", userId);

            await base.OnDisconnectedAsync(exception);
        }

        private string GetUserId()
        {
            var userId = Context.User?.GetUserId();
            return userId ?? throw new ArgumentNullException("O token não possui ID de usuário");
        }
    }
}