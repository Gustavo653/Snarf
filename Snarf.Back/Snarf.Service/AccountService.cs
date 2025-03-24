using Hangfire;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Serilog;
using Snarf.Domain.Base;
using Snarf.Domain.Entities;
using Snarf.Domain.Enum;
using Snarf.DTO;
using Snarf.DTO.Base;
using Snarf.Infrastructure.Repository;
using Snarf.Infrastructure.Service;
using System.Text.Json;

namespace Snarf.Service
{
    public class AccountService(UserManager<User> userManager,
                                SignInManager<User> signInManager,
                                IEmailService emailService,
                                IUserRepository userRepository,
                                ITokenService tokenService,
                                IPrivateChatMessageRepository privateChatMessageRepository,
                                IPublicChatMessageRepository publicChatMessageRepository,
                                IBlockedUserRepository blockUserRepository,
                                S3Service s3Service) : IAccountService
    {
        private async Task<SignInResult> CheckUserPassword(User user, UserLoginDTO userLoginDTO)
        {
            try
            {
                return await signInManager.CheckPasswordSignInAsync(user, userLoginDTO.Password, false);
            }
            catch (Exception ex)
            {
                throw new Exception($"Erro ao verificar senha do usuário. Erro: {ex.Message}");
            }
        }

        private async Task<User?> GetUserByEmail(string email)
        {
            try
            {
                return await userRepository.GetEntities().FirstOrDefaultAsync(x => x.NormalizedEmail == email.ToUpper());
            }
            catch (Exception ex)
            {
                throw new Exception($"Erro ao obter o usuário. Erro: {ex.Message}");
            }
        }

        public async Task<ResponseDTO> Login(UserLoginDTO userDTO)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var user = await GetUserByEmail(userDTO.Email);

                if (user == null)
                {
                    responseDTO.SetUnauthorized("Não autenticado! Verifique o email e a senha inserida!");
                    return responseDTO;
                }

                var password = await CheckUserPassword(user, userDTO);
                if (!password.Succeeded)
                {
                    responseDTO.SetUnauthorized("Não autenticado! Verifique o email e a senha inserida!");
                    return responseDTO;
                }

                responseDTO.Object = new
                {
                    userName = user.UserName,
                    role = user.Role.ToString(),
                    name = user.Name,
                    email = user.Email,
                    token = await tokenService.CreateToken(user)
                };
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }

            return responseDTO;
        }

        public async Task<ResponseDTO> GetUserInfo(Guid id, bool showSensitiveInfo)
        {
            ResponseDTO responseDTO = new();
            try
            {
                Log.Information("Obtendo o usuário atual: {email}", id);


                var data = await userRepository.GetEntities()
                                                          .Select(x => new
                                                          {
                                                              x.Id,
                                                              x.Email,
                                                              x.Name,
                                                              LastActivity = x.LastActivity.GetValueOrDefault().ToUniversalTime(),
                                                              x.LastLatitude,
                                                              x.LastLongitude,
                                                              x.ImageUrl,
                                                              BlockedUsers = showSensitiveInfo ? x.BlockedUsers.Select(x => new { x.Blocked.Id, x.Blocked.Name, x.Blocked.ImageUrl }) : null,
                                                              BlockedBy = showSensitiveInfo ? x.BlockedBy.Count : 0,
                                                              FavoriteChats = showSensitiveInfo ? x.FavoriteChats.Select(x => new { x.ChatUser.Name, x.ChatUser.ImageUrl }) : null,
                                                              FavoritedBy = showSensitiveInfo ? x.FavoritedBy.Count : 0,
                                                              ExtraVideoCallMinutes = showSensitiveInfo ? x.ExtraVideoCallMinutes : 0
                                                          })
                                                          .FirstOrDefaultAsync(x => x.Id == id.ToString());
                var a = JsonSerializer.Serialize(data);
                Log.Information(a);

                responseDTO.Object = data;
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }

            return responseDTO;
        }

        public async Task<ResponseDTO> CreateUser(UserDTO userDTO)
        {
            ResponseDTO responseDTO = new();
            try
            {
                if (string.IsNullOrEmpty(userDTO.Password))
                {
                    responseDTO.SetBadInput($"A senha é obrigatória para criar um usuário");
                    return responseDTO;
                }

                var user = await userManager.FindByEmailAsync(userDTO.Email);
                if (user != null)
                {
                    responseDTO.SetBadInput($"Já existe um usuário cadastrado com este email: {userDTO.Email}!");
                    return responseDTO;
                }

                var imageBytes = Convert.FromBase64String(userDTO.Image);
                var imageStream = new MemoryStream(imageBytes);
                var s3Service = new S3Service();
                var imageUrl = await s3Service.UploadFileAsync($"userImages/{Guid.NewGuid()}{Guid.NewGuid()}", imageStream, "image/jpeg");

                var userEntity = new User
                {
                    ImageUrl = imageUrl,
                    Name = userDTO.Name,
                    Role = RoleName.User,
                    Email = userDTO.Email,
                    NormalizedEmail = userDTO.Email.ToUpper(),
                    NormalizedUserName = userDTO.Email.ToUpper()
                };

                userEntity.PasswordHash = userManager.PasswordHasher.HashPassword(userEntity, userDTO.Password);

                await userRepository.InsertAsync(userEntity);
                await userRepository.SaveChangesAsync();
                await userManager.UpdateSecurityStampAsync(userEntity);
                Log.Information("Usuário persistido id: {id}", userEntity.Id);

                responseDTO.Object = userDTO;
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }

            return responseDTO;
        }

        public async Task<ResponseDTO> UpdateUser(Guid id, UserDTO userDTO)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var userEntity = await userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == id.ToString());
                if (userEntity == null)
                {
                    responseDTO.SetBadInput($"Usuário não encotrado com este id: {id}!");
                    return responseDTO;
                }

                var imageBytes = Convert.FromBase64String(userDTO.Image);
                var imageStream = new MemoryStream(imageBytes);
                var s3Service = new S3Service();
                try
                {
                    await s3Service.DeleteFileAsync(userEntity.ImageUrl);
                }
                catch (Exception ex)
                {
                    Log.Error(ex, "Erro ao deletar arquivo {media}", userEntity.ImageUrl);
                }
                var imageUrl = await s3Service.UploadFileAsync($"userImages/{Guid.NewGuid()}{Guid.NewGuid()}", imageStream, "image/jpeg");

                userEntity.ImageUrl = imageUrl;
                userEntity.Name = userDTO.Name;
                if (userDTO.Password != null)
                {
                    userEntity.PasswordHash = userManager.PasswordHasher.HashPassword(userEntity, userDTO.Password);
                    await userManager.UpdateSecurityStampAsync(userEntity);
                }

                await userRepository.SaveChangesAsync();
                Log.Information("Usuário persistido id: {id}", userEntity.Id);
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }

            return responseDTO;
        }

        public async Task<ResponseDTO> RemoveUser(Guid id)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var userEntity = await userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == id.ToString());
                if (userEntity == null)
                {
                    responseDTO.SetBadInput($"Usuário não encontrado com este id: {id}!");
                    return responseDTO;
                }

                var publicMessages = await publicChatMessageRepository.GetTrackedEntities().Where(x => x.SenderId == id.ToString()).ToListAsync();
                var privateMessages = await privateChatMessageRepository.GetTrackedEntities().Where(x => x.Sender.Id == id.ToString() || x.Receiver.Id == id.ToString()).ToListAsync();

                var medias = privateMessages.Where(x => x.Message.StartsWith("http")).Select(x => x.Message).ToList();
                medias.Add(userEntity.ImageUrl);
                var tasks = medias.Select(async media =>
                {
                    try
                    {
                        await s3Service.DeleteFileAsync(media);
                        Log.Information("Arquivo removido: {media}", media);
                    }
                    catch (Exception ex)
                    {
                        Log.Error(ex, "Erro ao deletar arquivo {media}", media);
                    }
                });
                await Task.WhenAll(tasks);

                publicChatMessageRepository.DeleteRange(publicMessages.ToArray());
                privateChatMessageRepository.DeleteRange(privateMessages.ToArray());
                userRepository.Delete(userEntity);

                await userRepository.SaveChangesAsync();
                Log.Information("Usuário removido id: {id}", userEntity.Id);
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }

            return responseDTO;
        }

        public async Task<ResponseDTO> RequestResetPassword(string email)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var user = await GetUserByEmail(email);
                if (user == null)
                {
                    responseDTO.SetBadInput($"Usuário não encontrado com o email: {email}");
                    return responseDTO;
                }

                BackgroundJob.Enqueue(() => emailService.SendEmail("Solicitação para redefinir senha - Snarf", emailService.BuildResetPasswordText(email, user.SecurityStamp!), email));
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> ResetPassword(UserEmailDTO userEmailDTO)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var user = await GetUserByEmail(userEmailDTO.Email);
                if (user == null)
                {
                    responseDTO.SetBadInput($"Usuário não encontrado com o email: {userEmailDTO.Email}");
                    return responseDTO;
                }

                if (user.SecurityStamp != userEmailDTO.Code)
                {
                    responseDTO.SetBadInput($"O código {userEmailDTO.Code} é inválido!");
                    return responseDTO;
                }

                userRepository.Attach(user);
                user.PasswordHash = userManager.PasswordHasher.HashPassword(user, userEmailDTO.Password);
                await userRepository.SaveChangesAsync();
                await userManager.UpdateSecurityStampAsync(user);
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> BlockUser(Guid blockerUserId, Guid blockedUserId)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var blockerUser = userRepository.GetTrackedEntities().FirstOrDefault(x => x.Id == blockerUserId.ToString());
                var blockedUser = userRepository.GetTrackedEntities().FirstOrDefault(x => x.Id == blockedUserId.ToString());

                if (blockerUser == null || blockedUser == null)
                {
                    responseDTO.SetBadInput("Usuário não encontrado!");
                    return responseDTO;
                }

                var blockeUserEntity = new BlockedUser
                {
                    Blocker = blockerUser,
                    Blocked = blockedUser
                };

                await blockUserRepository.InsertAsync(blockeUserEntity);
                await blockUserRepository.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> UnblockUser(Guid blockerUserId, Guid blockedUserId)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var blockeUserEntity = await blockUserRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Blocker.Id == blockerUserId.ToString() && x.Blocked.Id == blockedUserId.ToString());
                if (blockeUserEntity == null)
                {
                    responseDTO.SetBadInput("Usuário bloqueado não encontrado!");
                    return responseDTO;
                }
                blockUserRepository.Delete(blockeUserEntity);
                await blockUserRepository.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> ReportUserPublicMessage(Guid messageId)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var message = await publicChatMessageRepository.GetTrackedEntities().Include(x => x.Sender).FirstOrDefaultAsync(x => x.Id == messageId);
                if (message == null)
                {
                    responseDTO.SetBadInput("Mensagem não encontrada!");
                    return responseDTO;
                }
                var email = BackgroundJob.Enqueue(() => emailService.SendEmail("Denúncia de chat público - Snarf", emailService.BuildReportedMessageText(message.Message, message.CreatedAt, message.Sender.Name, message.Sender.Email), "oficial.snarf@gmail.com"));
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> ReportUser(Guid userId)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var user = await userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == userId.ToString());
                if (user == null)
                {
                    responseDTO.SetBadInput("Usuário não encontrado!");
                    return responseDTO;
                }
                var email = BackgroundJob.Enqueue(() => emailService.SendEmail("Denúncia de perfil - Snarf", emailService.BuildReportedUser(user.Name, user.Email), "oficial.snarf@gmail.com"));
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> AddExtraMinutes(AddExtraMinutesDTO addExtraMinutesDTO)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var user = await userRepository.GetTrackedEntities().FirstOrDefaultAsync(x => x.Id == addExtraMinutesDTO.UserId.ToString());
                if (user == null)
                {
                    responseDTO.SetBadInput("Usuário não encontrado!");
                    return responseDTO;
                }
                Log.Information($"Adicionando {addExtraMinutesDTO.Minutes} minutos ao usuário {user.Id} ID assinatura:{addExtraMinutesDTO.SubscriptionId} Token:{addExtraMinutesDTO.Token}");
                user.ExtraVideoCallMinutes += addExtraMinutesDTO.Minutes;
                await userRepository.SaveChangesAsync();
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }
            return responseDTO;
        }

        public async Task<ResponseDTO> ChangeEmail(Guid userId, string newEmail, string currentPassword)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var user = await userRepository.GetTrackedEntities()
                                               .FirstOrDefaultAsync(x => x.Id == userId.ToString());
                if (user == null)
                {
                    responseDTO.SetBadInput("Usuário não encontrado!");
                    return responseDTO;
                }

                var signInResult = await signInManager.CheckPasswordSignInAsync(user, currentPassword, false);
                if (!signInResult.Succeeded)
                {
                    responseDTO.SetBadInput("Senha atual incorreta!");
                    return responseDTO;
                }

                var existingUser = await userManager.FindByEmailAsync(newEmail);
                if (existingUser != null && existingUser.Id != user.Id)
                {
                    responseDTO.SetBadInput("Já existe um usuário com este email!");
                    return responseDTO;
                }

                user.Email = newEmail;
                user.NormalizedEmail = newEmail.ToUpper();
                user.UserName = newEmail;
                user.NormalizedUserName = newEmail.ToUpper();

                await userManager.UpdateSecurityStampAsync(user);
                await userRepository.SaveChangesAsync();

                responseDTO.Message = "Email alterado com sucesso!";
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }

            return responseDTO;
        }

        public async Task<ResponseDTO> ChangePassword(Guid userId, string oldPassword, string newPassword)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var user = await userRepository.GetTrackedEntities()
                                               .FirstOrDefaultAsync(x => x.Id == userId.ToString());
                if (user == null)
                {
                    responseDTO.SetBadInput("Usuário não encontrado!");
                    return responseDTO;
                }

                var signInResult = await signInManager.CheckPasswordSignInAsync(user, oldPassword, false);
                if (!signInResult.Succeeded)
                {
                    responseDTO.SetBadInput("Senha antiga incorreta!");
                    return responseDTO;
                }

                user.PasswordHash = userManager.PasswordHasher.HashPassword(user, newPassword);

                await userManager.UpdateSecurityStampAsync(user);
                await userRepository.SaveChangesAsync();

                responseDTO.Message = "Senha alterada com sucesso!";
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }

            return responseDTO;
        }

        public async Task<ResponseDTO> GetFirstMessageToday(Guid userid)
        {
            ResponseDTO responseDTO = new();
            try
            {
                var userEntity = await userRepository.GetTrackedEntities()
                    .FirstOrDefaultAsync(x => x.Id == userid.ToString());

                if (userEntity == null)
                {
                    responseDTO.SetBadInput($"Usuário não encontrado com este id: {userid}!");
                    return responseDTO;
                }

                var today = DateTime.UtcNow.Date;

                var publicMessage = await publicChatMessageRepository.GetTrackedEntities()
                    .Where(x => x.SenderId == userEntity.Id && x.CreatedAt.Date == today)
                    .OrderBy(x => x.CreatedAt)
                    .FirstOrDefaultAsync();

                var privateMessage = await privateChatMessageRepository.GetTrackedEntities()
                    .Where(x => x.Sender.Id == userEntity.Id && x.CreatedAt.Date == today)
                    .OrderBy(x => x.CreatedAt)
                    .FirstOrDefaultAsync();

                DateTime? firstMessage = (publicMessage, privateMessage) switch
                {
                    (null, null) => null,
                    (not null, null) => publicMessage.CreatedAt,
                    (null, not null) => privateMessage.CreatedAt,
                    _ => publicMessage.CreatedAt <= privateMessage.CreatedAt ? publicMessage.CreatedAt : privateMessage.CreatedAt
                };

                responseDTO.Object = new
                {
                    FirstMessageToday = firstMessage
                };
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }

            return responseDTO;
        }
    }
}
