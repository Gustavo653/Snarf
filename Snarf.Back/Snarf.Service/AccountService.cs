using Snarf.Domain.Base;
using Snarf.Domain.Enum;
using Snarf.DTO;
using Snarf.DTO.Base;
using Snarf.Infrastructure.Repository;
using Snarf.Infrastructure.Service;
using Snarf.Utils;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Serilog;

namespace Snarf.Service
{
    public class AccountService(UserManager<User> userManager,
                                SignInManager<User> signInManager,
                                IUserRepository userRepository,
                                ITokenService tokenService,
                                IHttpContextAccessor httpContextAccessor) : IAccountService
    {
        private ISession Session => httpContextAccessor.HttpContext!.Session;

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

        public async Task<ResponseDTO> GetCurrent()
        {
            ResponseDTO responseDTO = new();
            try
            {
                var email = Session.GetString(Consts.ClaimEmail)!;
                Log.Information("Obtendo o usuário atual: {email}", email);
                responseDTO.Object = await GetUserByEmail(email);
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

                userEntity.Name = userDTO.Name;
                userEntity.Email = userDTO.Email;
                if (!string.IsNullOrEmpty(userDTO.Password))
                {
                    userEntity.PasswordHash = userManager.PasswordHasher.HashPassword(userEntity, userDTO.Password);
                }

                await userRepository.SaveChangesAsync();
                Log.Information("Usuário atualizado id: {id}", userEntity.Id);

                responseDTO.Object = userDTO;
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

                await userManager.DeleteAsync(userEntity);
                Log.Information("Usuário removido id: {id}", userEntity.Id);

                responseDTO.Object = userEntity;
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }

            return responseDTO;
        }

        public async Task<ResponseDTO> GetUsers()
        {
            ResponseDTO responseDTO = new();
            try
            {
                responseDTO.Object = await userRepository.GetEntities()
                                                         .Where(x => x.Email != "admin@admin.com")
                                                         .Select(x => new
                                                         {
                                                             x.Id,
                                                             x.Name,
                                                             x.Email,
                                                             x.Role
                                                         }).ToListAsync();
            }
            catch (Exception ex)
            {
                responseDTO.SetError(ex);
            }

            return responseDTO;
        }
    }
}
