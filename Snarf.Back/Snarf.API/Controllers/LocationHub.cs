using Microsoft.AspNetCore.SignalR;
using Serilog;
using System.Collections.Concurrent;

public class LocationHub : Hub
{
    // Dicionário para armazenar a localização dos usuários
    private static readonly ConcurrentDictionary<string, (double latitude, double longitude)> _userLocations = new ConcurrentDictionary<string, (double, double)>();

    // Método chamado quando o cliente envia sua localização
    public async Task UpdateLocation(double latitude, double longitude)
    {
        Log.Warning($"{Context.ConnectionId} conectou");

        // Atualiza a localização do usuário conectado
        _userLocations[Context.ConnectionId] = (latitude, longitude);

        // Envia a localização para todos os outros clientes conectados
        await Clients.Others.SendAsync("ReceiveLocation", latitude, longitude);
    }

    // Método chamado quando um novo cliente se conecta
    public override async Task OnConnectedAsync()
    {
        Log.Warning($"{Context.ConnectionId} conectou");

        // Envia as localizações de todos os usuários para o novo cliente
        foreach (var userLocation in _userLocations)
        {
            await Clients.Caller.SendAsync("ReceiveLocation", userLocation.Value.latitude, userLocation.Value.longitude);
        }

        await base.OnConnectedAsync();
    }

    // Método chamado quando um cliente se desconecta
    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        var connectionId = Context.ConnectionId;
        Log.Warning($"{connectionId} desconectou");
        // Notifica todos os clientes sobre a desconexão do usuário
        await Clients.All.SendAsync("UserDisconnected", connectionId);

        // Remove a localização do usuário desconectado
        _userLocations.TryRemove(connectionId, out _);

        await base.OnDisconnectedAsync(exception);
    }

}
