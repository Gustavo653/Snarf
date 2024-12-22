using Snarf.DTO;
using Snarf.Infrastructure.Service;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Snarf.API.Controllers
{
    public class AccountController(IAccountService accountService) : BaseController
    {
        [HttpPost("Login")]
        [AllowAnonymous]
        public async Task<IActionResult> Login([FromBody] UserLoginDTO userLogin)
        {
            var user = await accountService.Login(userLogin);
            return StatusCode(user.Code, user);
        }

        [HttpPost("")]
        [AllowAnonymous]
        public async Task<IActionResult> CreateUser([FromBody] UserDTO userDTO)
        {
            var user = await accountService.CreateUser(userDTO);
            return StatusCode(user.Code, user);
        }

        [HttpPost("RequestResetPassword")]
        [AllowAnonymous]
        public async Task<IActionResult> RequestResetPassword([FromBody] string email)
        {
            var user = await accountService.RequestResetPassword(email);
            return StatusCode(user.Code, user);
        }

        [HttpPost("ResetPassword")]
        [AllowAnonymous]
        public async Task<IActionResult> ResetPassword([FromBody] UserEmailDTO userEmailDTO)
        {
            var user = await accountService.ResetPassword(userEmailDTO);
            return StatusCode(user.Code, user);
        }
    }
}