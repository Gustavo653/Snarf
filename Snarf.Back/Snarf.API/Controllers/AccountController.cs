using Snarf.DTO;
using Snarf.Infrastructure.Service;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

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

        [HttpGet("Current")]
        public async Task<IActionResult> GetUser([FromRoute] Guid id)
        {
            id = Guid.Parse(User.Claims.First(x => x.Type == ClaimTypes.NameIdentifier.ToString()).Value);
            var user = await accountService.GetCurrent(id);
            return StatusCode(user.Code, user);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateUser([FromRoute] Guid id, [FromBody] UserDTO userDTO)
        {
            id = Guid.Parse(User.Claims.First(x => x.Type == ClaimTypes.NameIdentifier.ToString()).Value);
            var user = await accountService.UpdateUser(id, userDTO);
            return StatusCode(user.Code, user);
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> RemoveUser([FromRoute] Guid id)
        {
            id = Guid.Parse(User.Claims.First(x => x.Type == ClaimTypes.NameIdentifier.ToString()).Value);
            var user = await accountService.RemoveUser(id);
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