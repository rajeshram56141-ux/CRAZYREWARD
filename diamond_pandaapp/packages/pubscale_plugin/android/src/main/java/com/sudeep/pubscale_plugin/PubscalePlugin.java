package com.sudeep.pubscale_plugin;

import android.app.Activity;
import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;

import com.pubscale.sdkone.offerwall.OfferWall;
import com.pubscale.sdkone.offerwall.OfferWallConfig;
import com.pubscale.sdkone.offerwall.models.OfferWallInitListener;
import com.pubscale.sdkone.offerwall.models.OfferWallListener;
import com.pubscale.sdkone.offerwall.models.Reward;
import com.pubscale.sdkone.offerwall.models.errors.InitError;

import java.util.HashMap;
import java.util.Objects;

public class PubscalePlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
  private Context context;
  private Activity activity;
  private MethodChannel channel;

  private static final int MAX_RETRY_ATTEMPTS = 3;

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding activityPluginBinding) {
    activity = activityPluginBinding.getActivity();
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    activity = null;
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding activityPluginBinding) {
    activity = activityPluginBinding.getActivity();
  }

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "pubscale_plugin");
    context = flutterPluginBinding.getApplicationContext();
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    if (call.method.equals("initSDK")) {
      HashMap<String, Object> args = call.arguments();
      if (args != null) {
        boolean success = initSdk(args);
        result.success(success);
      } else {
        Log.e("ERROR", "initSDK called with null arguments");
        result.error("ARGS_NULL", "initSDK called with null arguments", null);
      }
    } else if (call.method.equals("showOfferwall")) {
      boolean success = showOfferWall();
      result.success(success);
    } else {
      result.notImplemented();
    }
  }

  private boolean initSdk(final HashMap<String, Object> args) {
    String appId = Objects.requireNonNull(args.get("appId")).toString();
    String userId = Objects.requireNonNull(args.get("userId")).toString();

    final boolean[] success = {false};
    final int[] attempts = {0};

    while (attempts[0] < MAX_RETRY_ATTEMPTS) {
      attempts[0]++;
      final int currentAttempt = attempts[0];

      try {
        OfferWallConfig offerWallConfig =
                new OfferWallConfig.Builder(context, appId)
                        .setUniqueId(userId)
                        .setFullscreenEnabled(true)
                        .build();
        OfferWall.init(offerWallConfig, new OfferWallInitListener() {
          @Override
          public void onInitFailed(InitError initError) {
            Log.e("ERROR", "Initialization attempt " + currentAttempt + " failed: " + initError.toString());
          }

          @Override
          public void onInitSuccess() {
            Log.e("SUCCESS", "Pubscale Initialized");
            success[0] = true;
          }
        });

        if (success[0]) {
          break;
        }
      } catch (Exception e) {
        Log.e("ERROR", "Initialization attempt " + currentAttempt + " failed with exception: " + e.getMessage());
      }
    }
    return success[0];
  }


  private boolean showOfferWall() {
    int attempts = 0;
    while (attempts < MAX_RETRY_ATTEMPTS) {
      attempts++;
      try {
        OfferWall.launch(activity, new OfferWallListener() {
          @Override
          public void onRewardClaimed(Reward reward) {}

          @Override
          public void onOfferWallShowed() {
            Log.d("PUBSCALE", "Offer wall showed.");
          }

          @Override
          public void onOfferWallClosed() {
            Log.d("PUBSCALE", "Offer wall closed.");
          }

          @Override
          public void onFailed(@NonNull String message) {
            Log.d("PUBSCALE", "onFailed: " + message);
          }
        });
        return true;
      } catch (Exception e) {
        Log.e("ERROR", "Show attempt " + attempts + " failed with exception: " + e.getMessage());
      }
    }
    return false;
  }

  @Override
  public void onDetachedFromActivity() {
    activity = null;
  }
}
