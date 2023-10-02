#define MFR Plugin

namespace MFR {
    NSLock *lock;
    std::vector<bool> threads;
    std::vector<id<MTLCommandQueue>> queues;
    std::vector<CAMetalLayer *> layers;
}

#define IDENTIFIER @"Ae.MSL.Plugin"
#define METALLIB @"Plugin.metallib"

namespace Params {
    enum {
        INPUT = 0,
        NUM
    };
}

static PF_Err ParamsSetup(PF_InData *in_data, PF_OutData *out_data, PF_ParamDef *params[], PF_LayerDef *output) {
    
    PF_Err err = PF_Err_NONE;
    PF_ParamDef def;
    
    out_data->num_params = Params::NUM;
    
    return err;
}