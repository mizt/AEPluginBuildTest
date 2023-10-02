#import "AEConfig.h"
#import "AE_Effect.h"
#import "AE_Macros.h"
#import "Param_Utils.h"

#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>
#import <vector>

#import "Config.h"

namespace FileManager {
    NSString *resource(NSString *identifier, NSString *filename, NSString *ext) {
        return [[[NSBundle bundleWithIdentifier:identifier] URLForResource:filename withExtension:ext] path];
    }
    NSString *resource(NSString *identifier, NSString *filename) {
        return resource(identifier,[filename stringByDeletingPathExtension],[filename pathExtension]);
    }
    NSURL *URL(NSString *path) {
        return [NSURL fileURLWithPath:path];
    }
};

typedef unsigned int MESH_INDICES_TYPE;

class Plane {

    private:
    
        const int WIDTH = 32;
        const int HEIGHT = 32;
    
    public:

        int TEXCOORD_SIZE = WIDTH*HEIGHT*2;
        float *texcoord = new float[TEXCOORD_SIZE];

        int VERTICES_SIZE = WIDTH*HEIGHT*4;
        float *vertices = new float[VERTICES_SIZE];
            
        int INDICES_TYPE = sizeof(MESH_INDICES_TYPE);
        int INDICES_SIZE = (WIDTH-1)*(HEIGHT-1)*6;
        MESH_INDICES_TYPE *indices = new MESH_INDICES_TYPE[INDICES_SIZE];

        Plane() {
            
            for(int i=0; i<HEIGHT; i++) {
                for(int j=0; j<WIDTH; j++) {
                    int addr = (i*WIDTH+j)<<2;
                    this->vertices[addr+0] = (j/((float)(WIDTH-1)))*2.0-1.0;
                    this->vertices[addr+1] = (i/((float)(HEIGHT-1)))*2.0-1.0;
                    this->vertices[addr+2] = 0;
                    this->vertices[addr+3] = 1;
                }
            }
            
            for(int i=0; i<HEIGHT; i++) {
                for(int j=0; j<WIDTH; j++) {
                    int addr = (i*WIDTH+j)<<1;
                    this->texcoord[addr+0] = (j/(float)(WIDTH-1));
                    this->texcoord[addr+1] = 1-(i/(float)(HEIGHT-1));
                }
            }
            
            for(int i=0; i<HEIGHT-1; i++) {
                for(int j=0; j<WIDTH-1; j++) {
                    
                    int addr = (i*(WIDTH-1)+j)*6;
                    int o = i*WIDTH;
                    
                    this->indices[addr+0] = o+j;
                    this->indices[addr+1] = o+(j+WIDTH+1);
                    this->indices[addr+2] = o+(j+WIDTH);
                    
                    this->indices[addr+3] = o+j;
                    this->indices[addr+4] = o+(j+1);
                    this->indices[addr+5] = o+(j+WIDTH+1);
                }
            }
        }
    
        ~Plane() {
                        
            delete[] this->texcoord;
            delete[] this->vertices;
            delete[] this->indices;
        }
};

template <typename T>
class MetalLayer {
    
    private:
    
        T *_data;
        
        MTLRenderPassDescriptor *_renderPassDescriptor = nil;
            
        id<CAMetalDrawable> _metalDrawable  = nil;
        id<MTLTexture> _drawabletexture = nil;
            
        id<MTLBuffer> _verticesBuffer = nil;
        id<MTLBuffer> _indicesBuffer = nil;

        id<MTLLibrary> _library = nil;
        id<MTLRenderPipelineState> _renderPipelineState = nil;
        MTLRenderPipelineDescriptor *_renderPipelineDescriptor = nil;

        id<MTLRenderCommandEncoder> _renderEncoder = nil;

        bool _useArgumentEncoder = false;
        id<MTLArgumentEncoder> _argumentEncoder = nil;
            
        bool _isInit = false;
                        
        id<MTLTexture> _texture = nil;
        id<MTLBuffer> _texcoordBuffer = nil;

        id<MTLBuffer> _argumentEncoderBuffer = nil;

        id<MTLTexture> _depthTex = nil;
        id<MTLDepthStencilState> _depthState = nil;
    
        bool updateShader(id<MTLDevice> device) {
            
            id<MTLFunction> vertexFunction = [this->_library newFunctionWithName:@"vertexShader"];
            if(!vertexFunction) return false;
            id<MTLFunction> fragmentFunction = [this->_library newFunctionWithName:@"fragmentShader"];
            if(!fragmentFunction) return false;
            
            if(this->_useArgumentEncoder) this->_argumentEncoder = [fragmentFunction newArgumentEncoderWithBufferIndex:0];
            
            this->_renderPipelineDescriptor.vertexFunction = vertexFunction;
            this->_renderPipelineDescriptor.fragmentFunction = fragmentFunction;
            NSError *error = nil;
            this->_renderPipelineState = [device newRenderPipelineStateWithDescriptor:this->_renderPipelineDescriptor error:&error];
            if(error||!this->_renderPipelineState) return true;
            return false;
        }
    
        bool setupShader(id<MTLDevice> device) {
            
            this->_renderPipelineDescriptor = [MTLRenderPipelineDescriptor new];
            this->_renderPipelineDescriptor.depthAttachmentPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
            this->_renderPipelineDescriptor.stencilAttachmentPixelFormat = MTLPixelFormatInvalid;
            this->_renderPipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
            this->_renderPipelineDescriptor.colorAttachments[0].blendingEnabled = NO;
            
            return this->updateShader(device);
        }
    
    public:
        
        id<MTLTexture> texture() {
            return this->_texture;
        }
    
        id<MTLTexture> drawableTexture() {
            return this->_drawabletexture;
        }
    
        bool init(id<MTLDevice> device, int width, int height, NSString *shader) {
            NSError *error = nil;
            this->_library = [device newLibraryWithURL:FileManager::URL(shader) error:&error];
            if(this->_library&&error==nil) {
                if(this->setupShader(device)) return false;
                this->_isInit = this->setup(device,width,height);
            }
            return this->_isInit;
        }
    
        bool setup(id<MTLDevice> device, int width, int height) {
            
            MTLTextureDescriptor *texDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:width height:height mipmapped:NO];
            if(!texDesc) return false;
            
            this->_texture = [device newTextureWithDescriptor:texDesc];
            if(!this->_texture) return false;
            
            MTLTextureDescriptor *depthTexDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatDepth32Float_Stencil8 width:width height:height mipmapped:NO];
            if(!depthTexDesc) return false;
            
            depthTexDesc.textureType = MTLTextureType2D;
            depthTexDesc.sampleCount = 1;
            depthTexDesc.usage |= MTLTextureUsageRenderTarget;
            depthTexDesc.storageMode = MTLStorageModePrivate;
         
            this->_depthTex = [device newTextureWithDescriptor:depthTexDesc];
            if(!this->_depthTex) return false;

            MTLDepthStencilDescriptor *depthDesc = [MTLDepthStencilDescriptor new];
            depthDesc.depthCompareFunction = MTLCompareFunctionLess;
            depthDesc.depthWriteEnabled = YES;
            this->_depthState = [device newDepthStencilStateWithDescriptor:depthDesc];
            
            this->_verticesBuffer = [device newBufferWithBytes:this->_data->vertices length:this->_data->VERTICES_SIZE*sizeof(float) options:MTLResourceCPUCacheModeDefaultCache];
            if(!this->_verticesBuffer) return false;
            
            this->_indicesBuffer = [device newBufferWithBytes:this->_data->indices length:this->_data->INDICES_SIZE*sizeof(this->_data->INDICES_TYPE) options:MTLResourceCPUCacheModeDefaultCache];
            if(!this->_indicesBuffer) return false;
           
            this->_texcoordBuffer = [device newBufferWithBytes:this->_data->texcoord length:this->_data->TEXCOORD_SIZE*sizeof(float) options:MTLResourceCPUCacheModeDefaultCache];
            if(!this->_texcoordBuffer) return false;
                                    
            this->_argumentEncoderBuffer = [device newBufferWithLength:sizeof(float)*[this->_argumentEncoder encodedLength] options:MTLResourceCPUCacheModeDefaultCache];

            [this->_argumentEncoder setArgumentBuffer:this->_argumentEncoderBuffer offset:0];
            [this->_argumentEncoder setTexture:this->_texture atIndex:0];
            
            return true;
        }
        
        id<MTLCommandBuffer> setupCommandBuffer(id<MTLCommandQueue> queue) {
                        
            id<MTLCommandBuffer> commandBuffer = [queue commandBuffer];
            MTLRenderPassColorAttachmentDescriptor *colorAttachment = this->_renderPassDescriptor.colorAttachments[0];
            colorAttachment.texture = this->_metalDrawable.texture;
            colorAttachment.loadAction  = MTLLoadActionClear;
            
            colorAttachment.clearColor  = MTLClearColorMake(0.0f,0.0f,0.0f,0.0f);
            colorAttachment.storeAction = MTLStoreActionStore;
            
            MTLRenderPassDepthAttachmentDescriptor *depthAttachment = this->_renderPassDescriptor.depthAttachment;
            depthAttachment.texture     = this->_depthTex;
            depthAttachment.loadAction  = MTLLoadActionClear;
            depthAttachment.storeAction = MTLStoreActionDontCare;
            depthAttachment.clearDepth  = 1.0;
            
            this->_renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:this->_renderPassDescriptor];
            [this->_renderEncoder setDepthStencilState:this->_depthState];

            [this->_renderEncoder setRenderPipelineState:this->_renderPipelineState];
            [this->_renderEncoder setVertexBuffer:this->_verticesBuffer offset:0 atIndex:0];
            [this->_renderEncoder setVertexBuffer:this->_texcoordBuffer offset:0 atIndex:1];

            [this->_renderEncoder useResource:this->_texture usage:MTLResourceUsageRead stages:MTLRenderStageFragment];
            [this->_renderEncoder setFragmentBuffer:this->_argumentEncoderBuffer offset:0 atIndex:0];

            if(this->_data->INDICES_TYPE==sizeof(unsigned short)) {
                [this->_renderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:this->_data->INDICES_SIZE indexType:MTLIndexTypeUInt16 indexBuffer:this->_indicesBuffer indexBufferOffset:0];
            }
            else {
                
                [this->_renderEncoder drawIndexedPrimitives:MTLPrimitiveTypeTriangle indexCount:this->_data->INDICES_SIZE indexType:MTLIndexTypeUInt32 indexBuffer:this->_indicesBuffer indexBufferOffset:0];
            }
            
            [this->_renderEncoder endEncoding];
            [commandBuffer presentDrawable:this->_metalDrawable];
            this->_drawabletexture = this->_metalDrawable.texture;
            
            return commandBuffer;
        }
        
        bool update(CAMetalLayer *layers, id<MTLCommandQueue> queue) {
            
            if(this->_isInit==false) return false;
            
            this->_metalDrawable = [layers nextDrawable];
            if(this->_metalDrawable) {
                this->_renderPassDescriptor = [MTLRenderPassDescriptor renderPassDescriptor];
                if(this->_renderPassDescriptor) {
                    id<MTLCommandBuffer> commandBuffer = this->setupCommandBuffer(queue);
                    if(commandBuffer) {
                        [commandBuffer commit];
                        [commandBuffer waitUntilCompleted];
                    }
                    commandBuffer = nil;
                    return true;
                }
            }
            else {
                this->_renderPassDescriptor = nil;
            }
            
            return false;
        }
    
        MetalLayer() {
            this->_data = new T();
            this->_useArgumentEncoder = true;
        }
        
        ~MetalLayer() {
            
            this->_texture = nil;
            this->_texcoordBuffer = nil;

            this->_argumentEncoderBuffer = nil;
            
            this->_depthTex = nil;
            this->_depthState = nil;
            
            delete this->_data;
            
            this->_renderPassDescriptor.colorAttachments[0].texture = nil;
            this->_renderPassDescriptor.colorAttachments[0] = nil;
            this->_renderPassDescriptor = nil;
                
            this->_metalDrawable  = nil;
            this->_drawabletexture = nil;
                
            this->_verticesBuffer = nil;
            this->_indicesBuffer = nil;
        
            this->_library = nil;
            this->_renderPipelineState = nil;
            
            this->_renderPipelineDescriptor.vertexFunction = nil;
            this->_renderPipelineDescriptor.fragmentFunction = nil;
            this->_renderPipelineDescriptor = nil;
            
            this->_renderEncoder = nil;
        }
};

static PF_Err GlobalSetup(PF_InData *in_data,PF_OutData *out_data,PF_ParamDef *params[],PF_LayerDef *output) {
    
    PF_Err 	err = PF_Err_NONE;

    out_data->my_version = PF_VERSION(2,0,0,PF_Stage_DEVELOP,0);
    out_data->out_flags = PF_OutFlag_WIDE_TIME_INPUT;
    out_data->out_flags2 = PF_OutFlag2_SUPPORTS_THREADED_RENDERING;

    return err;
}


static PF_Err Render(PF_InData *in_data, PF_OutData *out_data, PF_ParamDef *params[], PF_LayerDef *output) {
    
    PF_Err err = PF_Err_NONE;

    int width  = output->width;
    int height = output->height;
    
    unsigned int *dst = (unsigned int *)output->data;
    int dstRow = output->rowbytes>>2;
    
    bool fill = false;
    
    if(width>=256&&height>=256) {
                        
        PF_LayerDef *input = &params[Params::INPUT]->u.ld;
        
        if(input->width==width&&input->height==height)  {
            
            MetalLayer<Plane> *metal = new MetalLayer<Plane>();
            
            int tid = -1;
            [MFR::lock lock];
            @try {
                
                bool create = false;
                
                if(MFR::threads.size()==0) {
                    tid = 0;
                    create = true;
                }
                else {
                    tid = -1;
                    for(int k=0; k<MFR::threads.size(); k++) {
                        if(MFR::threads[k]==false) {
                            MFR::threads[k] = true;
                            tid = k;
                            break;;
                        }
                    }
                    if(tid==-1) {
                        tid = (int)MFR::threads.size();
                        create = true;
                    }
                }
                
                if(create) {
                    MFR::threads.push_back(true);
                    MFR::queues.push_back([MTLCreateSystemDefaultDevice() newCommandQueue]);
                    MFR::layers.push_back([CAMetalLayer layer]);
                    MFR::layers[tid].device = [MFR::queues[tid] device];
                    MFR::layers[tid].pixelFormat = MTLPixelFormatBGRA8Unorm;
                    MFR::layers[tid].colorspace = CGColorSpaceCreateDeviceRGB();
                    MFR::layers[tid].opaque = NO;
                    MFR::layers[tid].framebufferOnly = YES;
                    MFR::layers[tid].displaySyncEnabled = NO;
                }
            }
            @finally {
                [MFR::lock unlock];
            }
            
            id<MTLCommandQueue> queue = MFR::queues[tid];
            CAMetalLayer *layer = MFR::layers[tid];
            layer.drawableSize = CGSizeMake(width,height);
                        
            bool isInit = metal->init([queue device],width,height,FileManager::resource(IDENTIFIER,METALLIB));
            if(isInit) {
                
                unsigned int *buffer = new unsigned int[width*height];
                unsigned int *texture = new unsigned int[width*height];

                unsigned int *src = (unsigned int *)input->data;
                int srcRow = input->rowbytes>>2;
                
                for(int i=0; i<height; i++) {
                    for(int j=0; j<width; j++) {
                        unsigned int p = src[i*srcRow+j];
                        unsigned char a = p&0xFF;
                        unsigned char r = (p>>8)&0xFF;
                        unsigned char g = (p>>16)&0xFF;
                        unsigned char b = (p>>24)&0xFF;
                        texture[i*width+j] = a<<24|b<<16|g<<8|r;
                    }
                }
                
                [metal->texture() replaceRegion:MTLRegionMake2D(0,0,width,height) mipmapLevel:0 withBytes:texture bytesPerRow:width<<2];
                metal->update(layer,queue);
                [metal->drawableTexture() getBytes:buffer bytesPerRow:width<<2 fromRegion:MTLRegionMake2D(0,0,width,height) mipmapLevel:0];
                            
                
                for(int i=0; i<height; i++) {
                    for(int j=0; j<width; j++) {
                        unsigned int p = buffer[i*width+j];
                        unsigned char a = (p>>24)&0xFF;
                        unsigned char b = (p)&0xFF;
                        unsigned char g = (p>>8)&0xFF;
                        unsigned char r = (p>>16)&0xFF;
                        dst[i*dstRow+j] = b<<24|g<<16|r<<8|a;
                    }
                }
                                
                MFR::threads[tid] = false;
                
                delete[] buffer;
                delete[] texture;
                
                delete metal;
            }
            else {
                fill = true;
            }
            
        }
        else {
            fill = true;
        }
    }
    else {
        fill = true;
    }
    
    if(fill) {
        for(int i=0; i<height; i++) {
            for(int j=0; j<width; j++) {
                dst[i*dstRow+j] = 0xFF0000FF;
            }
        }
    }
    
    return err;
}

extern "C" {
    PF_Err EffectMain(PF_Cmd cmd, PF_InData *in_data, PF_OutData *out_data, PF_ParamDef *params[], PF_LayerDef *output) {
        
        PF_Err err = PF_Err_NONE;

        try {
            switch (cmd) {
                case PF_Cmd_GLOBAL_SETUP: err = GlobalSetup(in_data,out_data,params,output); break;
                case PF_Cmd_PARAMS_SETUP: err = ParamsSetup(in_data,out_data,params,output); break;
                case PF_Cmd_RENDER: {
                    @autoreleasepool {
                        err = Render(in_data,out_data,params,output); break;
                    }
                }
                default: break;
            }
        } catch(PF_Err &thrown_err) {
            err = thrown_err;
        }
        return err;
    }
}
