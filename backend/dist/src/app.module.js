"use strict";
var __decorate = (this && this.__decorate) || function (decorators, target, key, desc) {
    var c = arguments.length, r = c < 3 ? target : desc === null ? desc = Object.getOwnPropertyDescriptor(target, key) : desc, d;
    if (typeof Reflect === "object" && typeof Reflect.decorate === "function") r = Reflect.decorate(decorators, target, key, desc);
    else for (var i = decorators.length - 1; i >= 0; i--) if (d = decorators[i]) r = (c < 3 ? d(r) : c > 3 ? d(target, key, r) : d(target, key)) || r;
    return c > 3 && r && Object.defineProperty(target, key, r), r;
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppModule = void 0;
const common_1 = require("@nestjs/common");
const config_1 = require("@nestjs/config");
const prisma_module_1 = require("./prisma/prisma.module");
const auth_module_1 = require("./auth/auth.module");
const devices_module_1 = require("./devices/devices.module");
const vpn_module_1 = require("./vpn/vpn.module");
const billing_module_1 = require("./billing/billing.module");
const admin_module_1 = require("./admin/admin.module");
const diagnostics_module_1 = require("./diagnostics/diagnostics.module");
const port_forwarding_module_1 = require("./port-forwarding/port-forwarding.module");
const dedicated_ip_module_1 = require("./dedicated-ip/dedicated-ip.module");
const multihop_module_1 = require("./multihop/multihop.module");
let AppModule = class AppModule {
};
exports.AppModule = AppModule;
exports.AppModule = AppModule = __decorate([
    (0, common_1.Module)({
        imports: [
            config_1.ConfigModule.forRoot({
                isGlobal: true,
                envFilePath: '.env',
            }),
            prisma_module_1.PrismaModule,
            auth_module_1.AuthModule,
            devices_module_1.DevicesModule,
            vpn_module_1.VpnModule,
            billing_module_1.BillingModule,
            admin_module_1.AdminModule,
            diagnostics_module_1.DiagnosticsModule,
            port_forwarding_module_1.PortForwardingModule,
            dedicated_ip_module_1.DedicatedIpModule,
            multihop_module_1.MultiHopModule,
        ],
    })
], AppModule);
//# sourceMappingURL=app.module.js.map