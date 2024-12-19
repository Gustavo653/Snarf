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

        [HttpGet("Current")]
        public async Task<IActionResult> Current()
        {
            var user = await accountService.GetCurrent();
            return StatusCode(user.Code, user);
        }

        [HttpGet("")]
        public async Task<IActionResult> GetUsers()
        {
            var user = await accountService.GetUsers();
            return StatusCode(user.Code, user);
        }

        [HttpPost("")]
        public async Task<IActionResult> CreateUser([FromBody] UserDTO userDTO)
        {
            var user = await accountService.CreateUser(userDTO);
            return StatusCode(user.Code, user);
        }

        [HttpPut("{id:guid}")]
        public async Task<IActionResult> UpdateUser([FromRoute] Guid id, [FromBody] UserDTO userDTO)
        {
            var user = await accountService.UpdateUser(id, userDTO);
            return StatusCode(user.Code, user);
        }

        [HttpDelete("{id:guid}")]
        public async Task<IActionResult> RemoveUser([FromRoute] Guid id)
        {
            var user = await accountService.RemoveUser(id);
            return StatusCode(user.Code, user);
        }
    }
}