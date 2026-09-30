#ifndef RUNNER_VPN_CHANNEL_H_
#define RUNNER_VPN_CHANNEL_H_

#include <flutter/binary_messenger.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

void RegisterVpnChannel(flutter::BinaryMessenger* messenger);

#endif  // RUNNER_VPN_CHANNEL_H_
