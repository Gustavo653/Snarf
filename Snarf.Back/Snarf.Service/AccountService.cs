using Hangfire;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Serilog;
using Snarf.Domain.Base;
using Snarf.Domain.Entities;
using Snarf.Domain.Enum;
using Snarf.Domain.Enum.UserDetails;
using Snarf.DTO;
using Snarf.DTO.Base;
using Snarf.Infrastructure.Repository;
using Snarf.Infrastructure.Service;

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
                                IVideoCallLogRepository videoCallLogRepository,
                                IVideoCallPurchaseRepository videoCallPurchaseRepository,
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
            var responseDTO = new ResponseDTO();

            try
            {
                var startOfMonth = new DateTime(DateTime.UtcNow.Year, DateTime.UtcNow.Month, 1);

                int usedMinutes = 0;
                int purchasedMinutes = 0;
                int totalMonthlyLimit = 360;
                bool isVideoCallLimitReached = false;

                if (showSensitiveInfo)
                {
                    usedMinutes = await videoCallLogRepository.GetEntities()
                        .Where(x =>
                            (x.Caller.Id == id.ToString() || x.Callee.Id == id.ToString()) &&
                            x.StartTime >= startOfMonth &&
                            x.EndTime != null)
                        .SumAsync(x => x.DurationMinutes);

                    purchasedMinutes = await videoCallPurchaseRepository.GetEntities()
                        .Where(p =>
                            p.UserId == id.ToString() &&
                            p.PurchaseDate >= startOfMonth)
                        .SumAsync(p => p.Minutes);

                    totalMonthlyLimit = 360 + purchasedMinutes;
                    isVideoCallLimitReached = usedMinutes >= totalMonthlyLimit;
                }

                var data = await userRepository.GetEntities()
                    .Select(x => new
                    {
                        x.Id,
                        x.Email,
                        x.Name,
                        LastActivity = x.LastActivity.GetValueOrDefault().ToUniversalTime(),
                        x.LastLatitude,
                        x.LastLongitude,
                        x.GetFirstPhoto,

                        BlockedUsers = showSensitiveInfo
                                                   ? x.BlockedUsers
                                                        .Select(b => new { b.Blocked.Id, b.Blocked.Name, b.Blocked.GetFirstPhoto })
                                                        .ToList()
                                                   : null,
                        BlockedByCount = showSensitiveInfo ? x.BlockedBy.Count : 0,
                        FavoriteChats = showSensitiveInfo
                                                   ? x.FavoriteChats
                                                        .Select(f => new { f.ChatUser.Name, f.ChatUser.GetFirstPhoto })
                                                        .ToList()
                                                   : null,
                        FavoritedByCount = showSensitiveInfo ? x.FavoritedBy.Count : 0,

                        ExtraVideoCallMinutes = showSensitiveInfo ? purchasedMinutes : 0,
                        UsedVideoCallMinutes = showSensitiveInfo ? usedMinutes : 0,
                        MonthlyVideoCallLimit = showSensitiveInfo ? totalMonthlyLimit : 0,
                        IsVideoCallLimitReached = showSensitiveInfo ? isVideoCallLimitReached : false
                    })
                    .FirstOrDefaultAsync(x => x.Id == id.ToString());

                if (data == null)
                {
                    responseDTO.SetBadInput($"Usuário não encontrado com este id: {id}!");
                    return responseDTO;
                }

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
            var responseDTO = new ResponseDTO();
            try
            {
                if (string.IsNullOrEmpty(userDTO.Password))
                {
                    responseDTO.SetBadInput("A senha é obrigatória para criar um usuário");
                    return responseDTO;
                }

                if (await userManager.FindByEmailAsync(userDTO.Email) != null)
                {
                    responseDTO.SetBadInput($"Já existe um usuário cadastrado com este email: {userDTO.Email}!");
                    return responseDTO;
                }

                var userEntity = new User
                {
                    Name = userDTO.Name,
                    Email = userDTO.Email,
                    NormalizedEmail = userDTO.Email.ToUpper(),
                    NormalizedUserName = userDTO.Email.ToUpper(),
                    Role = RoleName.User,

                    Description = userDTO.Description,
                    BirthLatitude = userDTO.BirthLatitude,
                    BirthLongitude = userDTO.BirthLongitude,
                    LocationAvailability = userDTO.LocationAvailability,

                    Age = userDTO.Age,
                    ShowAge = userDTO.ShowAge ?? false,
                    HeightInCm = userDTO.Height,
                    ShowHeightInCm = userDTO.ShowHeightInCm ?? false,
                    WeightInKg = userDTO.Weight,
                    ShowWeightInKg = userDTO.ShowWeightInKg ?? false,
                    BodyType = userDTO.BodyType,
                    ShowBodyType = userDTO.ShowBodyType ?? false,

                    IsCircumcised = userDTO.IsCircumcised,
                    ShowIsCircumcised = userDTO.ShowIsCircumcised ?? false,
                    SizeInCm = userDTO.CircumferenceCm,
                    ShowSizeInCm = userDTO.ShowSizeInCm ?? false,

                    Spectrum = userDTO.Spectrum,
                    ShowSpectrum = userDTO.ShowSpectrum ?? false,
                    Attitude = userDTO.Attitude,
                    ShowAttitude = userDTO.ShowAttitude ?? false,
                    Expressions = userDTO.Expressions ?? new List<ExpressionStyle>(),
                    ShowExpressions = userDTO.ShowExpressions ?? false,

                    HostingStatus = userDTO.HostingStatus,
                    ShowHostingStatus = userDTO.ShowHostingStatus ?? false,
                    PublicPlace = userDTO.PublicPlace,
                    ShowPublicPlace = userDTO.ShowPublicPlace ?? false,
                    LookingFor = userDTO.LookingFor ?? new List<ExpressionStyle>(),
                    ShowLookingFor = userDTO.ShowLookingFor ?? false,

                    Kinks = userDTO.Kinks ?? new List<Kink>(),
                    ShowKinks = userDTO.ShowKinks ?? false,
                    Fetishes = userDTO.Fetishes ?? new List<Fetish>(),
                    ShowFetishes = userDTO.ShowFetishes ?? false,
                    Actions = userDTO.Actions ?? new List<Actions>(),
                    ShowActions = userDTO.ShowActions ?? false,
                    Interactions = userDTO.Interactions ?? new List<Interaction>(),
                    ShowInteractions = userDTO.ShowInteractions ?? false,

                    Practice = userDTO.Practice,
                    ShowPractice = userDTO.ShowPractice ?? false,
                    HivStatus = userDTO.HivStatus,
                    ShowHivStatus = userDTO.ShowHivStatus ?? false,
                    HivTestedDate = userDTO.HivTestedDate,
                    ShowHivTestedDate = userDTO.ShowHivTestedDate ?? false,
                    StiTestedDate = userDTO.StiTestedDate,
                    ShowStiTestedDate = userDTO.ShowStiTestedDate ?? false,

                    Immunizations = userDTO.Immunizations ?? new List<ImmunizationStatus>(),
                    ShowImmunizations = userDTO.ShowImmunizations ?? false,
                    DrugAbuse = userDTO.DrugAbuse ?? new List<DrugAbuse>(),
                    ShowDrugAbuse = userDTO.ShowDrugAbuse ?? false,
                    Carrying = userDTO.Carrying ?? new List<Carrying>(),
                    ShowCarrying = userDTO.ShowCarrying ?? false
                };

                userEntity.PasswordHash = userManager.PasswordHasher.HashPassword(userEntity, userDTO.Password);

                if (userDTO.Images != null && userDTO.Images.Any())
                {
                    int ordem = 1;
                    foreach (var base64 in userDTO.Images.Take(4))
                    {
                        var bytes = Convert.FromBase64String(base64);
                        using var stream = new MemoryStream(bytes);
                        var url = await s3Service.UploadFileAsync(
                            $"userImages/{Guid.NewGuid()}",
                            stream,
                            "image/jpeg"
                        );

                        userEntity.Photos.Add(new UserPhoto
                        {
                            Id = Guid.NewGuid(),
                            Url = url,
                            Order = ordem++
                        });
                    }
                }

                await userRepository.InsertAsync(userEntity);
                await userRepository.SaveChangesAsync();
                await userManager.UpdateSecurityStampAsync(userEntity);

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
            var responseDTO = new ResponseDTO();
            try
            {
                var userEntity = await userRepository
                    .GetTrackedEntities()
                    .Include(u => u.Photos)
                    .FirstOrDefaultAsync(x => x.Id == id.ToString());

                if (userEntity == null)
                {
                    responseDTO.SetBadInput($"Usuário não encontrado com este id: {id}!");
                    return responseDTO;
                }

                userEntity.Name = userDTO.Name;
                if (!string.IsNullOrEmpty(userDTO.Password))
                {
                    userEntity.PasswordHash = userManager.PasswordHasher.HashPassword(userEntity, userDTO.Password);
                    await userManager.UpdateSecurityStampAsync(userEntity);
                }

                userEntity.Description = userDTO.Description;
                userEntity.BirthLatitude = userDTO.BirthLatitude;
                userEntity.BirthLongitude = userDTO.BirthLongitude;
                userEntity.LocationAvailability = userDTO.LocationAvailability;

                userEntity.Age = userDTO.Age;
                userEntity.ShowAge = userDTO.ShowAge ?? false;
                userEntity.HeightInCm = userDTO.Height;
                userEntity.ShowHeightInCm = userDTO.ShowHeightInCm ?? false;
                userEntity.WeightInKg = userDTO.Weight;
                userEntity.ShowWeightInKg = userDTO.ShowWeightInKg ?? false;
                userEntity.BodyType = userDTO.BodyType;
                userEntity.ShowBodyType = userDTO.ShowBodyType ?? false;

                userEntity.IsCircumcised = userDTO.IsCircumcised;
                userEntity.ShowIsCircumcised = userDTO.ShowIsCircumcised ?? false;
                userEntity.SizeInCm = userDTO.CircumferenceCm;
                userEntity.ShowSizeInCm = userDTO.ShowSizeInCm ?? false;

                userEntity.Spectrum = userDTO.Spectrum;
                userEntity.ShowSpectrum = userDTO.ShowSpectrum ?? false;
                userEntity.Attitude = userDTO.Attitude;
                userEntity.ShowAttitude = userDTO.ShowAttitude ?? false;
                userEntity.Expressions = userDTO.Expressions ?? new List<ExpressionStyle>();
                userEntity.ShowExpressions = userDTO.ShowExpressions ?? false;

                userEntity.HostingStatus = userDTO.HostingStatus;
                userEntity.ShowHostingStatus = userDTO.ShowHostingStatus ?? false;
                userEntity.PublicPlace = userDTO.PublicPlace;
                userEntity.ShowPublicPlace = userDTO.ShowPublicPlace ?? false;
                userEntity.LookingFor = userDTO.LookingFor ?? new List<ExpressionStyle>();
                userEntity.ShowLookingFor = userDTO.ShowLookingFor ?? false;

                userEntity.Kinks = userDTO.Kinks ?? new List<Kink>();
                userEntity.ShowKinks = userDTO.ShowKinks ?? false;
                userEntity.Fetishes = userDTO.Fetishes ?? new List<Fetish>();
                userEntity.ShowFetishes = userDTO.ShowFetishes ?? false;
                userEntity.Actions = userDTO.Actions ?? new List<Actions>();
                userEntity.ShowActions = userDTO.ShowActions ?? false;
                userEntity.Interactions = userDTO.Interactions ?? new List<Interaction>();
                userEntity.ShowInteractions = userDTO.ShowInteractions ?? false;

                // Saúde
                userEntity.Practice = userDTO.Practice;
                userEntity.ShowPractice = userDTO.ShowPractice ?? false;
                userEntity.HivStatus = userDTO.HivStatus;
                userEntity.ShowHivStatus = userDTO.ShowHivStatus ?? false;
                userEntity.HivTestedDate = userDTO.HivTestedDate;
                userEntity.ShowHivTestedDate = userDTO.ShowHivTestedDate ?? false;
                userEntity.StiTestedDate = userDTO.StiTestedDate;
                userEntity.ShowStiTestedDate = userDTO.ShowStiTestedDate ?? false;

                userEntity.Immunizations = userDTO.Immunizations ?? new List<ImmunizationStatus>();
                userEntity.ShowImmunizations = userDTO.ShowImmunizations ?? false;
                userEntity.DrugAbuse = userDTO.DrugAbuse ?? new List<DrugAbuse>();
                userEntity.ShowDrugAbuse = userDTO.ShowDrugAbuse ?? false;
                userEntity.Carrying = userDTO.Carrying ?? new List<Carrying>();
                userEntity.ShowCarrying = userDTO.ShowCarrying ?? false;

                foreach (var photo in userEntity.Photos.ToList())
                {
                    try { await s3Service.DeleteFileAsync(photo.Url); } catch { }
                    userEntity.Photos.Remove(photo);
                }
                if (userDTO.Images != null && userDTO.Images.Any())
                {
                    int ordem = 1;
                    foreach (var base64 in userDTO.Images.Take(4))
                    {
                        var bytes = Convert.FromBase64String(base64);
                        using var stream = new MemoryStream(bytes);
                        var url = await s3Service.UploadFileAsync(
                            $"userImages/{Guid.NewGuid()}",
                            stream,
                            "image/jpeg"
                        );
                        userEntity.Photos.Add(new UserPhoto
                        {
                            Id = Guid.NewGuid(),
                            Url = url,
                            Order = ordem++
                        });
                    }
                }

                await userRepository.SaveChangesAsync();
                responseDTO.Object = new { userEntity.Id };
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
                var userEntity = await userRepository.GetTrackedEntities().Include(x => x.Photos).FirstOrDefaultAsync(x => x.Id == id.ToString());
                if (userEntity == null)
                {
                    responseDTO.SetBadInput($"Usuário não encontrado com este id: {id}!");
                    return responseDTO;
                }

                var publicMessages = await publicChatMessageRepository.GetTrackedEntities().Where(x => x.SenderId == id.ToString()).ToListAsync();
                var privateMessages = await privateChatMessageRepository.GetTrackedEntities().Where(x => x.Sender.Id == id.ToString() || x.Receiver.Id == id.ToString()).ToListAsync();

                var medias = privateMessages.Where(x => x.Message.StartsWith("http")).Select(x => x.Message).ToList();
                medias.AddRange(userEntity.Photos.Select(x => x.Url));
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

                userEntity.Photos.Clear();

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
            var response = new ResponseDTO();
            try
            {
                var user = await userRepository
                    .GetTrackedEntities()
                    .FirstOrDefaultAsync(u => u.Id == addExtraMinutesDTO.UserId.ToString());
                if (user == null)
                {
                    response.SetBadInput($"Usuário não encontrado: {addExtraMinutesDTO.UserId}");
                    return response;
                }

                var purchase = new VideoCallPurchase
                {
                    UserId = user.Id,
                    Minutes = addExtraMinutesDTO.Minutes,
                    PurchaseDate = DateTime.UtcNow,
                    SubscriptionId = addExtraMinutesDTO.SubscriptionId,
                    Token = addExtraMinutesDTO.Token
                };

                await videoCallPurchaseRepository.InsertAsync(purchase);
                await videoCallPurchaseRepository.SaveChangesAsync();

                response.Object = new
                {
                    purchase.Id,
                    purchase.Minutes,
                    purchase.PurchaseDate
                };
            }
            catch (Exception ex)
            {
                response.SetError(ex);
            }

            return response;
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
