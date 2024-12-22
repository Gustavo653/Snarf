using Hangfire;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Serilog;
using Snarf.Domain.Base;
using Snarf.Domain.Enum;
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
                                ITokenService tokenService) : IAccountService
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

                var userEntity = new User
                {
                    Name = userDTO.Name,
                    Role = RoleName.Admin,
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
    }
}
