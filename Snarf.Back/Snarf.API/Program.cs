using FirebaseAdmin;
using Google.Apis.Auth.OAuth2;
using Hangfire;
using Hangfire.Dashboard.BasicAuthorization;
using Hangfire.PostgreSql;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using Serilog;
using Snarf.API.Controllers;
using Snarf.DataAccess;
using Snarf.Domain.Base;
using Snarf.Domain.Enum;
using Snarf.Infrastructure.Repository;
using Snarf.Infrastructure.Service;
using Snarf.Persistence;
using Snarf.Service;
using Snarf.Utils;
using System.Text;
using System.Text.Json.Serialization;

namespace Snarf.API
{
    public class Program
    {
        public static void Main(string[] args)
        {
            AppContext.SetSwitch("Npgsql.EnableLegacyTimestampBehavior", true);
            AppContext.SetSwitch("Npgsql.DisableDateTimeInfinityConversions", true);
            var builder = WebApplication.CreateBuilder(args);
            var configuration = builder.Configuration;

            Log.Logger = new LoggerConfiguration()
            .MinimumLevel.Information()
            .Enrich.FromLogContext()
            .WriteTo.Console()
            .WriteTo.File(Path.Combine("logs", "log.txt"),
                rollingInterval: RollingInterval.Day,
                retainedFileCountLimit: 10,
                outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss.fff zzz} {CorrelationId} {Level:u3} {Username} {Message:lj}{Exception}{NewLine}")
            .CreateLogger();

            builder.Logging.ClearProviders();
            builder.Host.UseSerilog();

            string databaseSnarf = Environment.GetEnvironmentVariable("DatabaseConnection") ?? configuration.GetConnectionString("DatabaseConnection")!;

            builder.Services.AddDbContext<SnarfContext>(x =>
            {
                x.UseNpgsql(databaseSnarf);
                if (builder.Environment.IsDevelopment())
                {
                    x.EnableSensitiveDataLogging();
                    x.EnableDetailedErrors();
                }
            });

            builder.Services.AddHttpLogging(x =>
            {
                x.LoggingFields = Microsoft.AspNetCore.HttpLogging.HttpLoggingFields.All;
            });

            builder.Services.AddScoped<SessionMiddleware>();

            InjectUserDependencies(builder);

            InjectRepositoryDependencies(builder);
            InjectServiceDependencies(builder);

            SetupAuthentication(builder, configuration);

            builder.Services.AddSession();

            builder.Services.AddControllers()
                            .AddJsonOptions(options =>
                            {
                                options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
                            });

            builder.Services.AddOutputCache(x =>
            {
                x.AddPolicy("CacheImmutableResponse", OutputCachePolicy.Instance);
            });

            builder.Services.AddEndpointsApiExplorer();

            SetupSwaggerGen(builder);

            builder.Services.AddCors();

            builder.Services.AddHangfire(x =>
            {
                x.UsePostgreSqlStorage(options => options.UseNpgsqlConnection(databaseSnarf));
            });

            builder.Services.AddHangfireServer(x => x.WorkerCount = 10);

            builder.Services.AddMvc();
            builder.Services.AddRouting();

            builder.Services.AddSignalR();

            builder.Services.Configure<HubOptions>(options =>
            {
                options.MaximumReceiveMessageSize = 1024 * 1024 * 50;
            });

            var app = builder.Build();

            using (var scope = app.Services.CreateScope())
            {
                var db = scope.ServiceProvider.GetRequiredService<SnarfContext>();
                db.Database.Migrate();
                SeedAdminUser(scope.ServiceProvider).Wait();
            }

            app.UseHangfireDashboard("/hangfire", new DashboardOptions
            {
                Authorization = new[] { new BasicAuthAuthorizationFilter(
                    new BasicAuthAuthorizationFilterOptions
                    {
                        RequireSsl = false,
                        SslRedirect = false,
                        LoginCaseSensitive = true,
                        Users = new[]
                        {
                            new BasicAuthAuthorizationUser
                            {
                                Login = GetAdminEmail(),
                                PasswordClear = GetAdminPassword()

                            }
                        }
                    }) }
            });

            string firebaseCredentials = Environment.GetEnvironmentVariable("FirebaseCredentials") ?? configuration.GetConnectionString("FirebaseCredentials")!;
            FirebaseApp.Create(new AppOptions()
            {
                Credential = GoogleCredential.FromJson(firebaseCredentials)
            });

            app.UseSwagger();
            app.UseSwaggerUI();

            app.UseCors(corsPolicyBuilder =>
            {
                corsPolicyBuilder.AllowAnyMethod()
                       .AllowAnyOrigin()
                       .AllowAnyHeader();
            });

            app.UseSession();
            app.UseOutputCache();

            app.UseRouting();

            app.UseAuthentication();
            app.UseAuthorization();

            app.MapHub<SnarfHub>("/SnarfHub").RequireAuthorization();

            app.MapControllers();

            app.Run();
        }

        private static void SetupAuthentication(WebApplicationBuilder builder, ConfigurationManager configuration)
        {
            builder.Services.AddAuthentication(options =>
            {
                options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
                options.DefaultScheme = JwtBearerDefaults.AuthenticationScheme;
                options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
            })
            .AddJwtBearer(options =>
            {
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(configuration.GetValue<string>("TokenKey")!)),
                    ValidateLifetime = true,
                    ValidateIssuer = false,
                    ValidateAudience = false
                };
            });
        }

        private static void SetupSwaggerGen(WebApplicationBuilder builder)
        {
            builder.Services.AddSwaggerGen(options =>
            {
                options.SwaggerDoc("v1", new OpenApiInfo { Title = "Snarf.API", Version = "v1" });
                options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
                {
                    Description = @"JWT Authorization header usando Bearer.
                                Entre com 'Bearer ' [espaço] então coloque seu token.
                                Exemplo: 'Bearer 12345abcdef'",
                    Name = "Authorization",
                    In = ParameterLocation.Header,
                    Type = SecuritySchemeType.ApiKey,
                    Scheme = "Bearer"
                });

                options.AddSecurityRequirement(new OpenApiSecurityRequirement()
                {
                    {
                        new OpenApiSecurityScheme
                        {
                            Reference = new OpenApiReference
                            {
                                Type = ReferenceType.SecurityScheme,
                                Id = "Bearer"
                            },
                            Scheme = "oauth2",
                            Name = "Bearer",
                            In = ParameterLocation.Header
                        },
                        new List<string>()
                    }
                });
            });
        }

        private static void InjectUserDependencies(WebApplicationBuilder builder)
        {
            builder.Services.AddIdentityCore<User>(options =>
            {
                options.Password.RequireDigit = false;
                options.Password.RequireNonAlphanumeric = false;
                options.Password.RequireLowercase = false;
                options.Password.RequireUppercase = false;
                options.Password.RequiredLength = 4;
                options.User.RequireUniqueEmail = true;
            })
            .AddEntityFrameworkStores<SnarfContext>()
            .AddSignInManager()
            .AddDefaultTokenProviders();

            builder.Services.AddScoped<UserManager<User>>();
        }

        private static void InjectRepositoryDependencies(WebApplicationBuilder builder)
        {
            builder.Services.AddScoped<IUserRepository, UserRepository>();
            builder.Services.AddScoped<IVideoCallLogRepository, VideoCallLogRepository>();
            builder.Services.AddScoped<IPrivateChatMessageRepository, PrivateChatMessageRepository>();
            builder.Services.AddScoped<IPublicChatMessageRepository, PublicChatMessageRepository>();
            builder.Services.AddScoped<IFavoriteChatRepository, FavoriteChatRepository>();
            builder.Services.AddScoped<IBlockedUserRepository, BlockedUserRepository>();
        }

        private static void InjectServiceDependencies(WebApplicationBuilder builder)
        {
            builder.Services.AddScoped<IAccountService, AccountService>();
            builder.Services.AddScoped<S3Service>();
            builder.Services.AddScoped<IEmailService, EmailService>();
            builder.Services.AddScoped<ITokenService, TokenService>();
        }

        private static async Task SeedAdminUser(IServiceProvider serviceProvider)
        {
            var userManager = serviceProvider.GetRequiredService<UserManager<User>>();
            var adminEmail = GetAdminEmail();

            var adminUser = await userManager.FindByEmailAsync(adminEmail);
            var user = new User { Name = "Admin", ImageUrl = "", UserName = "admin", Email = adminEmail, Role = RoleName.Admin, EmailConfirmed = true };
            if (adminUser == null)
                await userManager.CreateAsync(user, GetAdminPassword());
        }

        private static string GetAdminEmail()
        {
            return "admin@admin.com";
        }

        private static string GetAdminPassword()
        {
            return "Admin@123";
        }
    }
}