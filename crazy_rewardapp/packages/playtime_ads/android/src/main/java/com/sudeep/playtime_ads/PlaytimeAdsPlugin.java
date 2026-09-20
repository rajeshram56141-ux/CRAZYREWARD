package com.sudeep.playtime_ads;

import android.app.Activity;
import android.content.Context;
import android.util.Log;

import androidx.annotation.NonNull;

import com.playtimeads.PlaytimeAds;
import com.playtimeads.listeners.OfferWallInitListener;

import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class PlaytimeAdsPlugin implements FlutterPlugin, MethodCallHandler, ActivityAware {
  private MethodChannel channel;
  private Context applicationContext;
  private Activity activity;

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
    applicationContext = flutterPluginBinding.getApplicationContext();
    channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "playtime_ads");
    channel.setMethodCallHandler(this);
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    channel.setMethodCallHandler(null);
  }

  @Override
  public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
    switch (call.method) {
      case "initSdk":
        String appKey = call.argument("appKey");
        String userId = call.argument("userId");

        if (appKey == null || userId == null) {
          result.success(false);
          return;
        }

        PlaytimeAds.getInstance().init(applicationContext, appKey, userId, new OfferWallInitListener() {
          @Override
          public void onInitSuccess() {
            Log.d("PlaytimeAds", "onInitSuccess");
            result.success(true);
          }

          @Override
          public void onAlreadyInitializing() {
            Log.d("PlaytimeAds", "onAlreadyInitializing");
            result.success(false);
          }

          @Override
          public void onInitFailed(String error) {
            Log.e("PlaytimeAds", "onInitFailed: " + error);
            result.success(false);
          }
        });
        break;

      case "launchOfferwall":
        if (PlaytimeAds.getInstance().isInitialized()) {
          if (activity != null) {
            PlaytimeAds.getInstance().open(activity);
            Log.e("PlaytimeAds", "Offerwall shown");
            result.success(true);
          } else {
            Log.e("PlaytimeAds", "Activity context is null");
            result.success(false);
          }
        } else {
          Log.e("PlaytimeAds", "SDK not initialized");
          result.success(false);
        }
        break;

      case "destroySdk":
        PlaytimeAds.getInstance().destroy();
        Log.e("PlaytimeAds", "SDK destroyed");
        result.success(true);
        break;

      default:
        result.notImplemented();
        break;
    }
  }

  // ActivityAware overrides
  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    activity = binding.getActivity();
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    activity = null;
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    activity = binding.getActivity();
  }

  @Override
  public void onDetachedFromActivity() {
    activity = null;
  }
}
