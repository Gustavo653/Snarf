using FirebaseAdmin.Messaging;
using Google.Apis.Storage.v1.Data;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Serilog;
using Snarf.DataAccess;
using Snarf.Domain.Entities;
using Snarf.DTO;
using Snarf.Infrastructure.Repository;
using Snarf.Service;
using Snarf.Utils;
using System.Collections.Concurrent;
using System.Text.Json;

namespace Snarf.API.Controllers
{
    public class SnarfHub(
        IUserRepository _userRepository,
        IPublicChatMessageRepository _publicChatMessageRepository,
        IPartyChatMessageRepository _partyChatMessageRepository,
        IPrivateChatMessageRepository _privateChatMessageRepository,
        IBlockedUserRepository _blockedUserRepository,
        IVideoCallLogRepository _videoCallLogRepository,
        IFavoriteChatRepository _favoriteChatRepository) : Hub
    {
        private static ConcurrentDictionary<string, List<string>> _userConnections = new();

        public async Task SendMessage(string jsonMessage)
        {
            var message = SignalRMessage.Deserialize(jsonMessage);

            switch (message.Type)
            {
                case nameof(SignalREventType.MapUpdateLocation):
                    await HandleMapUpdateLocation(message.Data);
                    break;

                case nameof(SignalREventType.PartyChatSendMessage):
                    await HandlePartyChatSendMessage(message.Data);
                    break;

                case nameof(SignalREventType.PartyChatDeleteMessage):
                    await HandlePartyChatDeleteMessage(message.Data);
                    break;

                case nameof(SignalREventType.PartyChatGetPreviousMessages):
                    await HandlePartyChatGetPreviousMessages();
                    break;

                case nameof(SignalREventType.PublicChatSendMessage):
                    await HandlePublicChatSendMessage(message.Data);
                    break;

                case nameof(SignalREventType.PublicChatDeleteMessage):
                    await HandlePublicChatDeleteMessage(message.Data);
                    break;

                case nameof(SignalREventType.PublicChatGetPreviousMessages):
                    await HandlePublicChatGetPreviousMessages();
                    break;

                case nameof(SignalREventType.PrivateChatSendMessage):
                    await HandlePrivateChatSendMessage(message.Data);
                    break;

                case nameof(SignalREventType.PrivateChatGetRecentChats):
                    await HandlePrivateChatGetRecentChats();
                    break;

                case nameof(SignalREventType.PrivateChatGetPreviousMessages):
                    await HandlePrivateChatGetPreviousMessages(message.Data);
                    break;

                case nameof(SignalREventType.PrivateChatMarkMessagesAsRead):
                    await HandlePrivateChatMarkMessagesAsRead(message.Data);
                    break;

                case nameof(SignalREventType.PrivateChatDeleteMessage):
                    await HandlePrivateChatDeleteMessage(message.Data);
                    break;

                case nameof(SignalREventType.PrivateChatDeleteChat):
                    await HandlePrivateChatDeleteChat(message.Data);
                    break;

                case nameof(SignalREventType.PrivateChatSendImage):
                    await HandlePrivateChatSendImage(message.Data);
                    break;

                case nameof(SignalREventType.PrivateChatSendAudio):
                    await HandlePrivateChatSendAudio(message.Data);
                    break;

                case nameof(SignalREventType.PrivateChatSendVideo):
                    await HandlePrivateChatSendVideo(message.Data);
                    break;

                case nameof(SignalREventType.PrivateChatGetFavorites):
                    await HandlePrivateChatGetFavorites();
                    break;

                case nameof(SignalREventType.PrivateChatAddFavorite):
                    await HandlePrivateChatAddFavorite(message.Data);
                    break;

                case nameof(SignalREventType.PrivateChatRemoveFavorite):
                    await HandlePrivateChatRemoveFavorite(message.Data);
                    break;

                case nameof(SignalREventType.PrivateChatReactToMessage):
                    await HandlePrivateChatReactToMessage(message.Data);
                    break;

                case nameof(SignalREventType.PrivateChatReplyToMessage):
                    await HandlePrivateChatReplyToMessage(message.Data);
                    break;

                case nameof(SignalREventType.VideoCallInitiate):
                    await HandleVideoCallInitiate(message.Data);
                    break;

                case nameof(SignalREventType.VideoCallAccept):
                    await HandleVideoCallAccept(message.Data);
                    break;

                case nameof(SignalREventType.VideoCallReject):
                    await HandleVideoCallReject(message.Data);
                    break;

                case nameof(SignalREventType.VideoCallEnd):
                    await HandleVideoCallEnd(message.Data);
                    break;

                default:
                    Log.Warning($"Evento desconhecido recebido: {message.Type}");
                    break;
            }
        }

        #region Métodos Principais

        private async Task HandleMapUpdateLocation(JsonElement data)
        {
            var userId = GetUserId();
            var location = JsonSerializer.Deserialize<LocationModel>(data.ToString());

            var user = await _userRepository.GetTrackedEntities()
                .Where(x => x.Id == userId)
                .FirstOrDefaultAsync();

            if (user == null) return;

            user.LastActivity = DateTime.Now;
            user.LastLatitude = location.Latitude;
            user.LastLongitude = location.Longitude;
            user.FcmToken = location.FcmToken;
            await _userRepository.SaveChangesAsync();

            Log.Information($"Localização atualizada: {userId} - ({location.Latitude}, {location.Longitude})");

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.MapReceiveLocation, new
            {
                userId,
                Latitude = location.Latitude,
                Longitude = location.Longitude,
                user.Name,
                userImage = user.ImageUrl,
                videoCall = location.VideoCall
            });

            await Clients.Others.SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandlePartyChatSendMessage(JsonElement data)
        {
            var userId = GetUserId();
            var text = data.GetProperty("Message").GetString();
            if (string.IsNullOrWhiteSpace(text)) return;

            var user = await _userRepository.GetTrackedEntities()
                .FirstOrDefaultAsync(x => x.Id == userId);

            if (user == null) return;

            var message = new PartyChatMessage
            {
                SenderId = userId,
                Message = text
            };

            await _partyChatMessageRepository.InsertAsync(message);
            await _partyChatMessageRepository.SaveChangesAsync();

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

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.PartyChatReceiveMessage, new
            {
                message.Id,
                CreatedAt = DateTime.Now,
                UserId = userId,
                UserName = user.Name,
                UserImage = user.ImageUrl,
                Latitude = user.LastLatitude,
                Longitude = user.LastLongitude,
                Message = text
            });

            await Clients.AllExcept(blockedConnectionIds).SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandlePartyChatDeleteMessage(JsonElement data)
        {
            var userId = GetUserId();
            var messageId = data.GetProperty("MessageId").GetString();

            var message = await _partyChatMessageRepository
                .GetTrackedEntities()
                .FirstOrDefaultAsync(m => m.Id == Guid.Parse(messageId))
                ?? throw new Exception("Mensagem não encontrada.");

            if (message.SenderId != userId)
                throw new Exception("Você não pode excluir mensagens de outro usuário.");

            message.Message = "Mensagem excluída";

            await _partyChatMessageRepository.SaveChangesAsync();
            Log.Information($"Mensagem {message.Id} do usuário {userId} marcada como excluída.");

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.PartyChatReceiveMessageDeleted, new
            {
                MessageId = message.Id,
                Message = "Mensagem excluída"
            });

            await Clients.All.SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandlePartyChatGetPreviousMessages()
        {
            var userId = GetUserId();
            var previousMessages = await _partyChatMessageRepository
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
                var jsonResponse = SignalRMessage.Serialize(SignalREventType.PartyChatReceiveMessage, message);
                await Clients.Caller.SendAsync("ReceiveMessage", jsonResponse);
            }
        }

        private async Task HandlePublicChatSendMessage(JsonElement data)
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

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.PublicChatReceiveMessage, new
            {
                message.Id,
                CreatedAt = DateTime.Now,
                UserId = userId,
                UserName = user.Name,
                UserImage = user.ImageUrl,
                Latitude = user.LastLatitude,
                Longitude = user.LastLongitude,
                Message = text
            });

            await Clients.AllExcept(blockedConnectionIds).SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandlePublicChatDeleteMessage(JsonElement data)
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

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.PublicChatReceiveMessageDeleted, new
            {
                MessageId = message.Id,
                Message = "Mensagem excluída"
            });

            await Clients.All.SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandlePublicChatGetPreviousMessages()
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
                var jsonResponse = SignalRMessage.Serialize(SignalREventType.PublicChatReceiveMessage, message);
                await Clients.Caller.SendAsync("ReceiveMessage", jsonResponse);
            }
        }

        private async Task HandlePrivateChatSendMessage(JsonElement data)
        {
            var senderUserId = GetUserId();
            var receiverUserId = data.GetProperty("ReceiverUserId").GetString();
            var messageText = data.GetProperty("Message").GetString();

            if (string.IsNullOrWhiteSpace(messageText)) return;

            var sender = await _userRepository.GetTrackedEntities()
                .FirstOrDefaultAsync(x => x.Id == senderUserId);
            var receiver = await _userRepository.GetTrackedEntities()
                .FirstOrDefaultAsync(x => x.Id == receiverUserId);

            if (sender == null || receiver == null)
            {
                throw new Exception("Usuário não encontrado");
            }

            var chatMessage = new PrivateChatMessage
            {
                Sender = sender,
                Receiver = receiver,
                Message = messageText,
                IsRead = false
            };
            chatMessage.SetCreatedAt(DateTime.Now);

            await _privateChatMessageRepository.InsertAsync(chatMessage);
            await _privateChatMessageRepository.SaveChangesAsync();

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.PrivateChatReceiveMessage, new
            {
                CreatedAt = chatMessage.CreatedAt,
                MessageId = chatMessage.Id,
                UserId = senderUserId,
                UserName = sender.Name,
                Message = messageText
            });
            await Clients.User(senderUserId).SendAsync("ReceiveMessage", jsonResponse);
            await Clients.User(receiverUserId).SendAsync("ReceiveMessage", jsonResponse);

            if (!string.IsNullOrWhiteSpace(receiver.FcmToken))
            {
                var notification = new FirebaseAdmin.Messaging.Notification
                {
                    Title = "Mensagem Recebida",
                    Body = $"Você recebeu uma mensagem privada!"
                };

                var message = new Message
                {
                    Token = receiver.FcmToken,
                    Notification = notification,
                };

                try
                {
                    string response = await FirebaseMessaging.DefaultInstance.SendAsync(message);
                    Log.Information($"Notificação enviada com sucesso: {response}");
                }
                catch (Exception ex)
                {
                    Log.Error($"Erro ao enviar notificação: {ex.Message}");
                }
            }
        }

        private async Task HandlePrivateChatGetRecentChats()
        {
            var userId = GetUserId();
            var messages = await _privateChatMessageRepository.GetEntities()
                .Where(m => m.Sender.Id == userId || m.Receiver.Id == userId)
                .Select(m => new
                {
                    SenderId = m.Sender.Id,
                    SenderName = m.Sender.Name,
                    SenderImage = m.Sender.ImageUrl,
                    SenderLastActivity = m.Sender.LastActivity,

                    ReceiverId = m.Receiver.Id,
                    ReceiverName = m.Receiver.Name,
                    ReceiverImage = m.Receiver.ImageUrl,
                    ReceiverLastActivity = m.Receiver.LastActivity,

                    m.Message,
                    m.CreatedAt,
                    m.IsRead,
                })
                .ToListAsync();

            var recentChats = messages
                .GroupBy(m => m.ReceiverId == userId ? m.SenderId : m.ReceiverId)
                .Select(group => new
                {
                    UserId = group.Key,
                    UserName = group.First().ReceiverId == userId ? group.First().SenderName : group.First().ReceiverName,
                    UserImage = group.First().ReceiverId == userId ? group.First().SenderImage : group.First().ReceiverImage,
                    LastActivity = group.First().ReceiverId == userId ? group.First().SenderLastActivity : group.First().ReceiverLastActivity,
                    LastMessage = group.OrderByDescending(m => m.CreatedAt).First().Message,
                    LastMessageDate = group.Max(m => m.CreatedAt),
                    UnreadCount = group.Count(m => m.ReceiverId == userId && !m.IsRead)
                })
                .OrderByDescending(c => c.LastMessageDate)
                .ToList();

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.PrivateChatReceiveRecentChats, recentChats);
            await Clients.Caller.SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandlePrivateChatGetPreviousMessages(JsonElement data)
        {
            var userId = GetUserId();
            var receiverUserId = data.GetProperty("ReceiverUserId").GetString();

            var previousMessages = await _privateChatMessageRepository.GetEntities()
                .Where(m => (m.Sender.Id == userId && m.Receiver.Id == receiverUserId) ||
                            (m.Sender.Id == receiverUserId && m.Receiver.Id == userId))
                .Select(x => new
                {
                    x.Id,
                    CreatedAt = x.CreatedAt.ToUniversalTime(),
                    SenderId = x.Sender.Id,
                    ReceiverId = x.Receiver.Id,
                    x.Message,
                    x.Reactions,
                    x.ReplyToMessageId
                })
                .OrderByDescending(m => m.CreatedAt)
                .Take(1000)
                .OrderBy(m => m.CreatedAt)
                .ToListAsync();

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.PrivateChatReceivePreviousMessages, previousMessages);
            await Clients.Caller.SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandlePrivateChatDeleteMessage(JsonElement data)
        {
            var messageId = data.GetProperty("MessageId").GetString();
            var userId = GetUserId();

            var message = await _privateChatMessageRepository
                .GetTrackedEntities()
                .Include(x => x.Receiver)
                .Include(x => x.Sender)
                .FirstOrDefaultAsync(m => m.Id.ToString() == messageId);

            if (message == null)
            {
                Log.Warning($"Mensagem {messageId} não encontrada para exclusão pelo usuário {userId}");
                throw new Exception("Mensagem não encontrada");
            }

            if (message.Sender.Id != userId && message.Receiver.Id != userId)
            {
                Log.Warning($"Usuário {userId} tentou excluir mensagem {messageId} sem permissão");
                throw new UnauthorizedAccessException("Você não tem permissão para excluir esta mensagem");
            }

            if (message.Message.StartsWith("https://"))
            {
                var s3Service = new S3Service();
                await s3Service.DeleteFileAsync(message.Message);
            }

            message.Message = "Mensagem excluída";
            await _privateChatMessageRepository.SaveChangesAsync();
            Log.Information($"Usuário {userId} excluiu a mensagem {messageId}");

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.PrivateChatReceiveMessageDeleted, new
            {
                MessageId = messageId,
            });
            await Clients.User(message.Sender.Id).SendAsync("ReceiveMessage", jsonResponse);
            await Clients.User(message.Receiver.Id).SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandlePrivateChatDeleteChat(JsonElement data)
        {
            var receiverUserId = data.GetProperty("ReceiverUserId").GetString();
            var userId = GetUserId();
            var messages = await _privateChatMessageRepository.GetTrackedEntities()
                .Include(x => x.Sender)
                .Include(x => x.Receiver)
                .Where(m => (m.Sender.Id == userId && m.Receiver.Id == receiverUserId) ||
                            (m.Sender.Id == receiverUserId && m.Receiver.Id == userId))
                .ToListAsync();

            foreach (var message in messages)
            {
                var jsonResponse = SignalRMessage.Serialize(SignalREventType.PrivateChatReceiveMessageDeleted, new
                {
                    MessageId = message.Id,
                });
                await Clients.User(message.Sender.Id).SendAsync("ReceiveMessage", jsonResponse);
                await Clients.User(message.Receiver.Id).SendAsync("ReceiveMessage", jsonResponse);

                if (message.Message.StartsWith("https://"))
                {
                    var s3Service = new S3Service();
                    await s3Service.DeleteFileAsync(message.Message);
                }
                _privateChatMessageRepository.Delete(message);
            }
            await _privateChatMessageRepository.SaveChangesAsync();
            Log.Information($"Usuário {userId} excluiu o chat com {receiverUserId}");
        }

        private async Task HandlePrivateChatSendImage(JsonElement data)
        {
            var receiverUserId = data.GetProperty("ReceiverUserId").GetString();
            var imageBase64 = data.GetProperty("Image").GetString();
            var fileName = data.GetProperty("FileName").GetString();
            var senderUserId = GetUserId();

            Log.Information($"Usuário {senderUserId} enviou uma imagem para {receiverUserId}.");

            var imageBytes = Convert.FromBase64String(imageBase64);
            using var imageStream = new MemoryStream(imageBytes);
            var s3Service = new S3Service();
            var imageUrl = await s3Service.UploadFileAsync($"images/{fileName}{Guid.NewGuid()}{Guid.NewGuid()}", imageStream, "image/jpeg");

            var sender = await _userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == senderUserId);
            var receiver = await _userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == receiverUserId);

            if (sender == null || receiver == null)
            {
                throw new Exception("Usuário não encontrado");
            }

            var chatMessage = new PrivateChatMessage
            {
                Sender = sender,
                Receiver = receiver,
                Message = imageUrl,
                IsRead = false
            };
            chatMessage.SetCreatedAt(DateTime.Now);

            await _privateChatMessageRepository.InsertAsync(chatMessage);
            await _privateChatMessageRepository.SaveChangesAsync();

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.PrivateChatReceiveMessage, new
            {
                MessageId = chatMessage.Id,
                UserId = senderUserId,
                UserName = sender.Name,
                Message = imageUrl
            });
            await Clients.User(senderUserId).SendAsync("ReceiveMessage", jsonResponse);
            await Clients.User(receiverUserId).SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandlePrivateChatMarkMessagesAsRead(JsonElement data)
        {
            var senderUserId = data.GetProperty("SenderUserId").GetString();
            var receiverUserId = GetUserId();
            var messages = await _privateChatMessageRepository.GetTrackedEntities()
                .Where(m => m.Sender.Id == senderUserId && m.Receiver.Id == receiverUserId && !m.IsRead)
                .ToListAsync();

            Log.Information($"Usuário {receiverUserId} leu {messages.Count} de {senderUserId}");

            foreach (var message in messages)
            {
                message.IsRead = true;
            }

            await _privateChatMessageRepository.SaveChangesAsync();
        }

        private async Task HandlePrivateChatSendAudio(JsonElement data)
        {
            var receiverUserId = data.GetProperty("ReceiverUserId").GetString();
            var audioBase64 = data.GetProperty("Audio").GetString();
            var fileName = data.GetProperty("FileName").GetString();
            var senderUserId = GetUserId();

            var sender = await _userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == senderUserId);
            var receiver = await _userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == receiverUserId);

            if (sender == null || receiver == null)
                throw new Exception("Usuário não encontrado");

            var audioBytes = Convert.FromBase64String(audioBase64);
            using var audioStream = new MemoryStream(audioBytes);
            var s3Service = new S3Service();
            var audioUrl = await s3Service.UploadFileAsync(
                $"audios/{fileName}{Guid.NewGuid()}",
                audioStream,
                "audio/mpeg"
            );

            var chatMessage = new PrivateChatMessage
            {
                Sender = sender,
                Receiver = receiver,
                Message = audioUrl,
                IsRead = false
            };
            chatMessage.SetCreatedAt(DateTime.Now);

            await _privateChatMessageRepository.InsertAsync(chatMessage);
            await _privateChatMessageRepository.SaveChangesAsync();

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.PrivateChatReceiveMessage, new
            {
                MessageId = chatMessage.Id,
                UserId = senderUserId,
                UserName = sender.Name,
                Message = audioUrl
            });

            await Clients.User(senderUserId).SendAsync("ReceiveMessage", jsonResponse);
            await Clients.User(receiverUserId).SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandlePrivateChatSendVideo(JsonElement data)
        {
            var receiverUserId = data.GetProperty("ReceiverUserId").GetString();
            var videoBase64 = data.GetProperty("Video").GetString();
            var fileName = data.GetProperty("FileName").GetString();
            var senderUserId = GetUserId();

            var sender = await _userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == senderUserId);
            var receiver = await _userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == receiverUserId);

            if (sender == null || receiver == null)
                throw new Exception("Usuário não encontrado");

            var videoBytes = Convert.FromBase64String(videoBase64);
            using var videoStream = new MemoryStream(videoBytes);
            var s3Service = new S3Service();
            var videoUrl = await s3Service.UploadFileAsync(
                $"videos/{fileName}{Guid.NewGuid()}",
                videoStream,
                "video/mp4"
            );

            var chatMessage = new PrivateChatMessage
            {
                Sender = sender,
                Receiver = receiver,
                Message = videoUrl,
                IsRead = false
            };
            chatMessage.SetCreatedAt(DateTime.Now);

            await _privateChatMessageRepository.InsertAsync(chatMessage);
            await _privateChatMessageRepository.SaveChangesAsync();

            var jsonResponse = SignalRMessage.Serialize(SignalREventType.PrivateChatReceiveMessage, new
            {
                MessageId = chatMessage.Id,
                UserId = senderUserId,
                UserName = sender.Name,
                Message = videoUrl
            });

            await Clients.User(senderUserId).SendAsync("ReceiveMessage", jsonResponse);
            await Clients.User(receiverUserId).SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandlePrivateChatGetFavorites()
        {
            var userId = GetUserId();
            var favorites = await _favoriteChatRepository.GetEntities()
                .Where(f => f.User.Id == userId)
                .Select(f => new { f.ChatUser.Id })
                .ToListAsync();
            var jsonResponse = SignalRMessage.Serialize(SignalREventType.PrivateChatReceiveFavorites, favorites);
            await Clients.Caller.SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandlePrivateChatAddFavorite(JsonElement data)
        {
            var userId = GetUserId();
            var chatUserId = data.GetProperty("ChatUserId").GetString();

            var user = await _userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == userId);
            var chatUser = await _userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == chatUserId);

            var favorite = new FavoriteChat
            {
                User = user!,
                ChatUser = chatUser!,
            };

            await _favoriteChatRepository.InsertAsync(favorite);
            await _favoriteChatRepository.SaveChangesAsync();

            Log.Information($"Usuário {userId} favoritou o chat com {chatUserId}");
        }

        private async Task HandlePrivateChatRemoveFavorite(JsonElement data)
        {
            var userId = GetUserId();
            var chatUserId = data.GetProperty("ChatUserId").GetString();

            var favorite = await _favoriteChatRepository.GetTrackedEntities()
                .FirstOrDefaultAsync(f => f.User.Id == userId && f.ChatUser.Id == chatUserId);

            if (favorite != null)
            {
                _favoriteChatRepository.Delete(favorite);
                await _favoriteChatRepository.SaveChangesAsync();
                Log.Information($"Usuário {userId} removeu o favorito do chat com {chatUserId}");
            }
        }

        private async Task HandlePrivateChatReactToMessage(JsonElement data)
        {
            var userId = GetUserId();
            var messageId = data.GetProperty("MessageId").GetString();
            var reaction = data.GetProperty("Reaction").GetString();

            var guid = Guid.Parse(messageId);
            var messageObj = await _privateChatMessageRepository
                .GetTrackedEntities()
                .Include(m => m.Sender)
                .Include(m => m.Receiver)
                .FirstOrDefaultAsync(m => m.Id == guid) ??
                throw new Exception("Mensagem não encontrada para reagir.");

            messageObj.Reactions ??= [];

            if (string.IsNullOrEmpty(reaction))
            {
                messageObj.Reactions.Remove(userId);
            }
            else
            {
                messageObj.Reactions[userId] = reaction;
            }

            await _privateChatMessageRepository.SaveChangesAsync();

            var jsonResponse = SignalRMessage.Serialize(
                SignalREventType.PrivateChatReceiveReaction,
                new
                {
                    MessageId = messageObj.Id,
                    Reaction = reaction,
                    ReactorUserId = userId
                }
            );

            await Clients.User(messageObj.Sender.Id).SendAsync("ReceiveMessage", jsonResponse);
            await Clients.User(messageObj.Receiver.Id).SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandlePrivateChatReplyToMessage(JsonElement data)
        {
            var senderUserId = GetUserId();
            var receiverUserId = data.GetProperty("ReceiverUserId").GetString();
            var originalMessageId = data.GetProperty("OriginalMessageId").GetString();
            var newMessageText = data.GetProperty("Message").GetString();

            var sender = await _userRepository.GetTrackedEntities()
                .FirstOrDefaultAsync(x => x.Id == senderUserId);
            var receiver = await _userRepository.GetTrackedEntities()
                .FirstOrDefaultAsync(x => x.Id == receiverUserId);

            if (sender == null || receiver == null)
                throw new Exception("Usuário não encontrado.");

            var chatMessage = new PrivateChatMessage
            {
                Sender = sender,
                Receiver = receiver,
                Message = newMessageText,
                IsRead = false,
                ReplyToMessageId = Guid.Parse(originalMessageId)
            };
            chatMessage.SetCreatedAt(DateTime.Now);

            await _privateChatMessageRepository.InsertAsync(chatMessage);
            await _privateChatMessageRepository.SaveChangesAsync();

            var jsonResponse = SignalRMessage.Serialize(
                SignalREventType.PrivateChatReceiveReply,
                new
                {
                    CreatedAt = chatMessage.CreatedAt,
                    MessageId = chatMessage.Id,
                    UserId = senderUserId,
                    UserName = sender.Name,
                    Message = newMessageText,
                    OriginalMessageId = originalMessageId
                }
            );

            await Clients.User(senderUserId).SendAsync("ReceiveMessage", jsonResponse);
            await Clients.User(receiverUserId).SendAsync("ReceiveMessage", jsonResponse);
        }

        private async Task HandleVideoCallInitiate(JsonElement data)
        {
            var callerUserId = GetUserId();
            var targetUserId = data.GetProperty("TargetUserId").GetString();

            if (await IsMonthlyLimitReached(targetUserId) || await IsMonthlyLimitReached(callerUserId))
            {
                var rejectedMessage = SignalRMessage.Serialize(
                    SignalREventType.VideoCallReject,
                    new
                    {
                        reason = "O limite de 360 minutos foi atingido no mês."
                    }
                );
                await Clients.User(callerUserId).SendAsync("ReceiveMessage", rejectedMessage);
                await Clients.User(targetUserId).SendAsync("ReceiveMessage", rejectedMessage);
                return;
            }

            if (!_userConnections.ContainsKey(targetUserId))
            {
                var response = SignalRMessage.Serialize(
                    SignalREventType.VideoCallReject,
                    new { reason = "User offline" }
                );
                await Clients.User(callerUserId).SendAsync("ReceiveMessage", response);
                return;
            }

            var roomId = Guid.NewGuid().ToString("N");

            var callerName = await _userRepository.GetEntities()
                .Where(x => x.Id == callerUserId)
                .Select(x => x.Name)
                .FirstOrDefaultAsync();

            var incomingCallMessage = SignalRMessage.Serialize(
                SignalREventType.VideoCallIncoming,
                new
                {
                    roomId,
                    callerUserId,
                    callerName
                }
            );
            await Clients.User(targetUserId).SendAsync("ReceiveMessage", incomingCallMessage);

            var callInitiatedMessage = SignalRMessage.Serialize(
                SignalREventType.VideoCallInitiate,
                new { roomId, targetUserId }
            );
            await Clients.User(callerUserId).SendAsync("ReceiveMessage", callInitiatedMessage);
        }

        private async Task HandleVideoCallAccept(JsonElement data)
        {
            var targetUserId = GetUserId();
            var callerUserId = data.GetProperty("CallerUserId").GetString();
            var roomId = data.GetProperty("RoomId").GetString();

            var caller = await _userRepository.GetTrackedEntities()
                .FirstOrDefaultAsync(x => x.Id == callerUserId);
            var callee = await _userRepository.GetTrackedEntities()
                .FirstOrDefaultAsync(x => x.Id == targetUserId);

            var callLog = new VideoCallLog
            {
                RoomId = roomId,
                Caller = caller,
                Callee = callee,
                StartTime = DateTime.Now
            };
            await _videoCallLogRepository.InsertAsync(callLog);
            await _videoCallLogRepository.SaveChangesAsync();

            var acceptedMessage = SignalRMessage.Serialize(
                SignalREventType.VideoCallAccept,
                new
                {
                    roomId,
                    targetUserId
                }
            );
            await Clients.User(callerUserId).SendAsync("ReceiveMessage", acceptedMessage);
        }

        private async Task HandleVideoCallReject(JsonElement data)
        {
            var targetUserId = GetUserId();
            var callerUserId = data.GetProperty("CallerUserId").GetString();
            var roomId = data.GetProperty("RoomId").GetString();

            var rejectedMessage = SignalRMessage.Serialize(
                SignalREventType.VideoCallReject,
                new
                {
                    roomId,
                    targetUserId
                }
            );
            await Clients.User(callerUserId).SendAsync("ReceiveMessage", rejectedMessage);
        }

        private async Task HandleVideoCallEnd(JsonElement data)
        {
            var userId = GetUserId();
            var roomId = data.GetProperty("RoomId").GetString();

            var endMessage = SignalRMessage.Serialize(
                SignalREventType.VideoCallEnd,
                new
                {
                    roomId,
                    EndedByUserId = userId
                }
            );
            await Clients.All.SendAsync("ReceiveMessage", endMessage);
            Log.Information($"Usuário {userId} encerrou a chamada {roomId}");

            var callLog = await _videoCallLogRepository.GetTrackedEntities()
                .Include(x => x.Caller)
                .Include(x => x.Callee)
                .FirstOrDefaultAsync(x => x.RoomId == roomId);

            if (callLog != null && callLog.EndTime == null)
            {
                callLog.EndTime = DateTime.Now;
                callLog.DurationMinutes = (int)(callLog.EndTime.Value - callLog.StartTime).TotalMinutes;
                await _videoCallLogRepository.SaveChangesAsync();
            }
        }

        #endregion

        #region Conexões e Helpers

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

                    // 1) Localizar chamadas em aberto (EndTime == null) envolvendo este usuário
                    var ongoingCalls = await _videoCallLogRepository.GetEntities()
                        .Include(x => x.Caller)
                        .Include(x => x.Callee)
                        .Where(x =>
                            x.EndTime == null &&
                            (x.Caller.Id == userId || x.Callee.Id == userId)
                        ).ToListAsync();

                    foreach (var call in ongoingCalls)
                    {
                        // 2) Ajustar EndTime e DurationMinutes
                        call.EndTime = DateTime.Now;
                        call.DurationMinutes = (int)(call.EndTime.Value - call.StartTime).TotalMinutes;
                        await _videoCallLogRepository.SaveChangesAsync();

                        // 3) Opcional: notificar outras partes que a chamada foi finalizada
                        var endMessage = SignalRMessage.Serialize(
                            SignalREventType.VideoCallEnd,
                            new
                            {
                                RoomId = call.RoomId,
                                EndedByUserId = userId
                            }
                        );
                        // Se quiser notificar só o outro usuário, use Clients.User(...) 
                        // ou se preferir avisar todo mundo, use Clients.All:
                        await Clients.All.SendAsync("ReceiveMessage", endMessage);

                        Log.Information($"Chamada {call.RoomId} encerrada para o usuário {userId} no OnDisconnectedAsync.");
                    }
                }
            }

            // Notificar outros que esse usuário saiu
            var jsonResponse = SignalRMessage.Serialize(SignalREventType.UserDisconnected, new { userId });
            await Clients.Others.SendAsync("ReceiveMessage", jsonResponse);

            await base.OnDisconnectedAsync(exception);
        }


        private async Task<bool> IsMonthlyLimitReached(string userId)
        {
            var startOfMonth = new DateTime(DateTime.Now.Year, DateTime.Now.Month, 1);

            var totalMinutesUsedThisMonth = await _videoCallLogRepository.GetEntities()
                .Where(x => (x.Caller.Id == userId || x.Callee.Id == userId)
                            && x.StartTime >= startOfMonth
                            && x.EndTime != null)
                .SumAsync(x => x.DurationMinutes);

            var user = await _userRepository.GetTrackedEntities()
                .FirstOrDefaultAsync(u => u.Id == userId);

            if (user == null) return true;

            var totalMonthlyLimit = 360 + user.ExtraVideoCallMinutes;

            return totalMinutesUsedThisMonth >= totalMonthlyLimit;
        }


        private string GetUserId()
        {
            return Context.User?.GetUserId() ?? throw new ArgumentNullException("O token não possui ID de usuário");
        }

        private class LocationModel
        {
            public double Latitude { get; set; }
            public double Longitude { get; set; }
            public string FcmToken { get; set; }
            public bool VideoCall { get; set; }
        }

        #endregion
    }
}