"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
var __metadata = (this && this.__metadata) || function (k, v) {
    if (typeof Reflect === "object" && typeof Reflect.metadata === "function") return Reflect.metadata(k, v);
};
var __param = (this && this.__param) || function (paramIndex, decorator) {
    return function (target, key) { decorator(target, key, paramIndex); }
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.VpnController = void 0;
const common_1 = require("@nestjs/common");
const vpn_service_1 = require("./vpn.service");
const connect_dto_1 = require("./dto/connect.dto");
const jwt_auth_guard_1 = require("../auth/guards/jwt-auth.guard");
const current_user_decorator_1 = require("../auth/decorators/current-user.decorator");
let VpnController = class VpnController {
    constructor(vpnService) {
        this.vpnService = vpnService;
    }
    async listServers() {
        return this.vpnService.listServers();
    }
    async connect(userId, dto) {
        return this.vpnService.connect(userId, dto);
    }
    async disconnect(userId, dto) {
        return this.vpnService.disconnect(userId, dto);
    }
};
exports.VpnController = VpnController;
__decorate([
    (0, common_1.Get)('servers'),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", []),
    __metadata("design:returntype", Promise)
], VpnController.prototype, "listServers", null);
__decorate([
    (0, common_1.Post)('connect'),
    (0, common_1.HttpCode)(common_1.HttpStatus.OK),
    __param(0, (0, current_user_decorator_1.CurrentUser)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, connect_dto_1.ConnectVpnDto]),
    __metadata("design:returntype", Promise)
], VpnController.prototype, "connect", null);
__decorate([
    (0, common_1.Post)('disconnect'),
    (0, common_1.HttpCode)(common_1.HttpStatus.OK),
    __param(0, (0, current_user_decorator_1.CurrentUser)('id')),
    __param(1, (0, common_1.Body)()),
    __metadata("design:type", Function),
    __metadata("design:paramtypes", [String, connect_dto_1.DisconnectVpnDto]),
    __metadata("design:returntype", Promise)
], VpnController.prototype, "disconnect", null);
exports.VpnController = VpnController = __decorate([
    (0, common_1.Controller)('vpn'),
    (0, common_1.UseGuards)(jwt_auth_guard_1.JwtAuthGuard),
    __metadata("design:paramtypes", [vpn_service_1.VpnService])
], VpnController);
//# sourceMappingURL=vpn.controller.js.map