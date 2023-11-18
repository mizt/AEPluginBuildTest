#import "AEConfig.h"
#import "AE_Effect.h"
#import "AE_Macros.h"
#import "Param_Utils.h"

#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>
#import <vector>

#import "Config.h"

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
    
    float scaleX = (float)in_data->downsample_x.num/(float)in_data->downsample_x.den;
    float scaleY = (float)in_data->downsample_y.num/(float)in_data->downsample_y.den;
    
    if(scaleX==1&&scaleY==1&&width==4&&height==4) {
                        
        PF_LayerDef *input = &params[Params::INPUT]->u.ld;
        
        if(input->width==4&&input->height==4)  {
            
            /*
            float identity[4*4] = {
                1.0,0.0,0.0,0.0,
                0.0,1.0,0.0,0.0,
                0.0,0.0,1.0,0.0,
                0.0,0.0,0.0,1.0,
            };
            */
            
            unsigned int *src = (unsigned int *)input->data;
            int srcRow = input->rowbytes>>2;
            
            for(int i=0; i<4; i++) {
                for(int j=0; j<4; j++) {
                    
                    unsigned int p = src[i*srcRow+j];
                    
                    unsigned char a = (p)&0xFF;
                    unsigned char r = (p>>8)&0xFF;
                    unsigned char g = (p>>16)&0xFF;
                    unsigned char b = (p>>24)&0xFF;
                    
                    unsigned int u32 = a<<24|b<<16|g<<8|r;
                    float f32 = *((float *)(&u32));
                    u32 = *((unsigned int *)(&f32));
                    
                    a = (u32>>24)&0xFF;;
                    r = (u32)&0xFF;
                    g = (u32>>8)&0xFF;
                    b = (u32>>16)&0xFF;
                    
                    dst[i*dstRow+j] = b<<24|g<<16|r<<8|a;
                }
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
