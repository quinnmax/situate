function agent = initialize(p)

    persistent agent_base;
    persistent p_old;
    
    if ~exist('p','var') || isempty(p)
        p = [];
    end
    
    if isempty(agent_base) || ~isequal(p,p_old)
        agent_base                           = [];
        agent_base.type                      = 'scout';
        agent_base.interest                  = [];
        agent_base.urgency                   = 1;
        agent_base.box.r0rfc0cf              = [];
        agent_base.box.xywh                  = [];
        agent_base.box.xcycwh                = [];
        agent_base.box.aspect_ratio          = [];
        agent_base.box.area_ratio            = [];
        agent_base.support.internal          = NaN;
        agent_base.support.external          = NaN;
        agent_base.support.total             = NaN;
        agent_base.support.GROUND_TRUTH      = NaN;
        agent_base.support.sample_densities  = NaN;
        agent_base.support.sample_densities_prior  = NaN;
        agent_base.eval_function             = []; % not really using it right now :/
        agent_base.GT_label_raw = [];
        agent_base.history = 'blank';
        agent_base.generation    = 0;
        agent_base.had_offspring = false;
    
        if ~isempty(p)
            agent_base.urgency  = p.agent_urgency_defaults.scout;
        end
        
        p_old = p;
    end
   
    agent = agent_base;
    
end
