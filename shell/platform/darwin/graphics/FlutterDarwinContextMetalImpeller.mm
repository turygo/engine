// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#import "flutter/shell/platform/darwin/graphics/FlutterDarwinContextMetalImpeller.h"

#include "flutter/common/graphics/persistent_cache.h"
#include "flutter/fml/logging.h"
#include "flutter/impeller/renderer/backend/metal/context_mtl.h"
#include "flutter/shell/common/context_options.h"
#import "flutter/shell/platform/darwin/common/framework/Headers/FlutterMacros.h"
#include "impeller/entity/mtl/entity_shaders.h"
#include "impeller/entity/mtl/modern_shaders.h"
#include "impeller/scene/shaders/mtl/scene_shaders.h"

FLUTTER_ASSERT_ARC

static std::shared_ptr<impeller::ContextMTL> CreateImpellerContext() {
  std::vector<std::shared_ptr<fml::Mapping>> shader_mappings = {
      std::make_shared<fml::NonOwnedMapping>(impeller_entity_shaders_data,
                                             impeller_entity_shaders_length),
      std::make_shared<fml::NonOwnedMapping>(impeller_scene_shaders_data,
                                             impeller_scene_shaders_length),
      std::make_shared<fml::NonOwnedMapping>(impeller_modern_shaders_data,
                                             impeller_modern_shaders_length),
  };
  auto context = impeller::ContextMTL::Create(shader_mappings, "Impeller Library");
  if (!context) {
    FML_LOG(ERROR) << "Could not create Metal Impeller Context.";
    return nullptr;
  }
  FML_LOG(ERROR) << "Using the Impeller rendering backend.";

  return context;
}

@implementation FlutterDarwinContextMetalImpeller

- (instancetype)init {
  self = [super init];
  if (self != nil) {
    _context = CreateImpellerContext();
    id<MTLDevice> device = _context->GetMTLDevice();
    if (!device) {
      FML_DLOG(ERROR) << "Could not acquire Metal device.";
      return nil;
    }

    CVMetalTextureCacheRef textureCache;
    CVReturn cvReturn = CVMetalTextureCacheCreate(kCFAllocatorDefault,  // allocator
                                                  nil,           // cache attributes (nil default)
                                                  device,        // metal device
                                                  nil,           // texture attributes (nil default)
                                                  &textureCache  // [out] cache
    );

    if (cvReturn != kCVReturnSuccess) {
      FML_DLOG(ERROR) << "Could not create Metal texture cache.";
      return nil;
    }
    _textureCache.Reset(textureCache);
  }
  return self;
}

- (FlutterDarwinExternalTextureMetal*)
    createExternalTextureWithIdentifier:(int64_t)textureID
                                texture:(NSObject<FlutterTexture>*)texture {
  return [[FlutterDarwinExternalTextureMetal alloc] initWithTextureCache:_textureCache
                                                               textureID:textureID
                                                                 texture:texture
                                                          enableImpeller:YES];
}

@end
