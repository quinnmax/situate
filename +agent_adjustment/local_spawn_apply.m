
function agent_pool = local_spawn_apply( model, agent_to_expand, agent_pool, image  )
        
    % agent_pool = local_spawn_apply( model, agent_to_expand, agent_pool, image  );
    %
    % this is meant to take an agent and spawn a set of scouts that are
    % focusesed on the same object, but nearby boxes. those boxes are:
    %   shifted slightly {up, down, left, right}
    %   slightly {taller and thinner, shorter and wider}
    %   slightly {larger, smaller}

    im_size = [size(image,1) size(image,2)];
    
    if ~exist('model','var') || isempty(model) || ~isstruct(model) || ~isfield(model,'step_ratio') || isempty(model.step_ratio) || model.step_ratio <= 0
        model = [];
        model.step_ratio = .1;
    end
    
    new_agent_template = agent_to_expand;
    new_agent_template.type = 'scout';
    new_agent_template.urgency = 1;
    new_agent_template.support.internal     = 0;
    new_agent_template.support.external     = 0;
    new_agent_template.support.total        = 0;
    new_agent_template.support.GROUND_TRUTH = 0;
    new_agent_template.GT_label_raw = [];
    
    box_w  = new_agent_template.box.xywh(3);
    box_h  = new_agent_template.box.xywh(4);
    
    step_w = model.step_ratio * box_w;
    step_h = model.step_ratio * box_h;
    step_w = round(step_w);
    step_h = round(step_h);
    
    new_agents = [];
    
    % agent up
        new_agent = new_agent_template;
        r0 = new_agent.box.r0rfc0cf(1) - step_h;
        rf = new_agent.box.r0rfc0cf(2) - step_h;
        c0 = new_agent.box.r0rfc0cf(3);
        cf = new_agent.box.r0rfc0cf(4);
        r0 = max(1,round(r0)); rf = min(im_size(1),round(rf)); c0 = max(1,round(c0)); cf = min(im_size(2),round(cf));
        if r0>=1 && c0>=1 && rf<=im_size(1) && cf<=im_size(2) && rf>r0 && cf>c0
            x  = c0; y  = r0; w  = cf-c0+1; h  = rf-r0+1; xc = x+w/2; yc = y+w/2;
            new_agent.box.r0rfc0cf = [r0 rf c0 cf];
            new_agent.box.xywh     = [ x  y  w  h];
            new_agent.box.xcycwh   = [xc yc  w  h];
            new_agent.box.aspect_ratio = w/h;
            new_agent.box.area_ratio   = (w*h) / (im_size(1)*im_size(2));
            if isempty(new_agents), new_agents = new_agent; else new_agents(end+1) = new_agent; end
        end
            
    % agent down
        new_agent = new_agent_template;
        r0 = new_agent.box.r0rfc0cf(1) + step_h;
        rf = new_agent.box.r0rfc0cf(2) + step_h;
        c0 = new_agent.box.r0rfc0cf(3);
        cf = new_agent.box.r0rfc0cf(4);
        r0 = max(1,round(r0)); rf = min(im_size(1),round(rf)); c0 = max(1,round(c0)); cf = min(im_size(2),round(cf));
        if r0>=1 && c0>=1 && rf<=im_size(1) && cf<=im_size(2) && rf>r0 && cf>c0
            x  = c0; y  = r0; w  = cf-c0+1; h  = rf-r0+1; xc = x+w/2; yc = y+w/2;
            new_agent.box.r0rfc0cf = [r0 rf c0 cf];
            new_agent.box.xywh     = [ x  y  w  h];
            new_agent.box.xcycwh   = [xc yc  w  h];
            new_agent.box.aspect_ratio = w/h;
            new_agent.box.area_ratio   = (w*h) / (im_size(1)*im_size(2));
            if isempty(new_agents), new_agents = new_agent; else new_agents(end+1) = new_agent; end
        end
        
    % agent left
        new_agent = new_agent_template;
        r0 = new_agent.box.r0rfc0cf(1);
        rf = new_agent.box.r0rfc0cf(2);
        c0 = new_agent.box.r0rfc0cf(3) - step_w;
        cf = new_agent.box.r0rfc0cf(4) - step_h;
        r0 = max(1,round(r0)); rf = min(im_size(1),round(rf)); c0 = max(1,round(c0)); cf = min(im_size(2),round(cf));
        if r0>=1 && c0>=1 && rf<=im_size(1) && cf<=im_size(2) && rf>r0 && cf>c0
            x  = c0; y  = r0; w  = cf-c0+1; h  = rf-r0+1; xc = x+w/2; yc = y+w/2;
            new_agent.box.r0rfc0cf = [r0 rf c0 cf];
            new_agent.box.xywh     = [ x  y  w  h];
            new_agent.box.xcycwh   = [xc yc  w  h];
            new_agent.box.aspect_ratio = w/h;
            new_agent.box.area_ratio   = (w*h) / (im_size(1)*im_size(2));
            if isempty(new_agents), new_agents = new_agent; else new_agents(end+1) = new_agent; end
        end
        
    % agent right
        new_agent = new_agent_template;
        r0 = new_agent.box.r0rfc0cf(1);
        rf = new_agent.box.r0rfc0cf(2);
        c0 = new_agent.box.r0rfc0cf(3) + step_w;
        cf = new_agent.box.r0rfc0cf(4) + step_h;
        r0 = max(1,round(r0)); rf = min(im_size(1),round(rf)); c0 = max(1,round(c0)); cf = min(im_size(2),round(cf));
        if r0>=1 && c0>=1 && rf<=im_size(1) && cf<=im_size(2) && rf>r0 && cf>c0
            x  = c0; y  = r0; w  = cf-c0+1; h  = rf-r0+1; xc = x+w/2; yc = y+w/2;
            new_agent.box.r0rfc0cf = [r0 rf c0 cf];
            new_agent.box.xywh     = [ x  y  w  h];
            new_agent.box.xcycwh   = [xc yc  w  h];
            new_agent.box.aspect_ratio = w/h;
            new_agent.box.area_ratio   = (w*h) / (im_size(1)*im_size(2));
            if isempty(new_agents), new_agents = new_agent; else new_agents(end+1) = new_agent; end
        end
        
    % agent bigger
        new_agent = new_agent_template;
        r0 = new_agent.box.r0rfc0cf(1) - step_h/2;
        rf = new_agent.box.r0rfc0cf(2) + step_h/2;
        c0 = new_agent.box.r0rfc0cf(3) - step_w/2;
        cf = new_agent.box.r0rfc0cf(4) + step_w/2;
        r0 = max(1,round(r0)); rf = min(im_size(1),round(rf)); c0 = max(1,round(c0)); cf = min(im_size(2),round(cf));
        if r0>=1 && c0>=1 && rf<=im_size(1) && cf<=im_size(2) && rf>r0 && cf>c0
            x  = c0; y  = r0; w  = cf-c0+1; h  = rf-r0+1; xc = x+w/2; yc = y+w/2;
            new_agent.box.r0rfc0cf = [r0 rf c0 cf];
            new_agent.box.xywh     = [ x  y  w  h];
            new_agent.box.xcycwh   = [xc yc  w  h];
            new_agent.box.aspect_ratio = w/h;
            new_agent.box.area_ratio   = (w*h) / (im_size(1)*im_size(2));
            if isempty(new_agents), new_agents = new_agent; else new_agents(end+1) = new_agent; end
        end
        
    % agent smaller
        new_agent = new_agent_template;
        r0 = new_agent.box.r0rfc0cf(1) + step_h/2;
        rf = new_agent.box.r0rfc0cf(2) - step_h/2;
        c0 = new_agent.box.r0rfc0cf(3) + step_w/2;
        cf = new_agent.box.r0rfc0cf(4) - step_w/2;
        r0 = max(1,round(r0)); rf = min(im_size(1),round(rf)); c0 = max(1,round(c0)); cf = min(im_size(2),round(cf));
        if r0>=1 && c0>=1 && rf<=im_size(1) && cf<=im_size(2) && rf>r0 && cf>c0
            x  = c0; y  = r0; w  = cf-c0+1; h  = rf-r0+1; xc = x+w/2; yc = y+w/2;
            new_agent.box.r0rfc0cf = [r0 rf c0 cf];
            new_agent.box.xywh     = [ x  y  w  h];
            new_agent.box.xcycwh   = [xc yc  w  h];
            new_agent.box.aspect_ratio = w/h;
            new_agent.box.area_ratio   = (w*h) / (im_size(1)*im_size(2));
            if isempty(new_agents), new_agents = new_agent; else new_agents(end+1) = new_agent; end
        end
        
    % agent taller
        new_agent = new_agent_template;
        r0 = new_agent.box.r0rfc0cf(1) - step_h/2;
        rf = new_agent.box.r0rfc0cf(2) + step_h/2;
        c0 = new_agent.box.r0rfc0cf(3) + step_w/2;
        cf = new_agent.box.r0rfc0cf(4) - step_w/2;
        r0 = max(1,round(r0)); rf = min(im_size(1),round(rf)); c0 = max(1,round(c0)); cf = min(im_size(2),round(cf));
        if r0>=1 && c0>=1 && rf<=im_size(1) && cf<=im_size(2) && rf>r0 && cf>c0
            x  = c0; y  = r0; w  = cf-c0+1; h  = rf-r0+1; xc = x+w/2; yc = y+w/2;
            new_agent.box.r0rfc0cf = [r0 rf c0 cf];
            new_agent.box.xywh     = [ x  y  w  h];
            new_agent.box.xcycwh   = [xc yc  w  h];
            new_agent.box.aspect_ratio = w/h;
            new_agent.box.area_ratio   = (w*h) / (im_size(1)*im_size(2));
            if isempty(new_agents), new_agents = new_agent; else new_agents(end+1) = new_agent; end
        end
        
    % agent wider
        new_agent = new_agent_template;
        r0 = new_agent.box.r0rfc0cf(1) + step_h/2;
        rf = new_agent.box.r0rfc0cf(2) - step_h/2;
        c0 = new_agent.box.r0rfc0cf(3) - step_w/2;
        cf = new_agent.box.r0rfc0cf(4) + step_w/2;
        r0 = max(1,round(r0)); rf = min(im_size(1),round(rf)); c0 = max(1,round(c0)); cf = min(im_size(2),round(cf));
        if r0>=1 && c0>=1 && rf<=im_size(1) && cf<=im_size(2) && rf>r0 && cf>c0
            x  = c0; y  = r0; w  = cf-c0+1; h  = rf-r0+1; xc = x+w/2; yc = y+w/2;
            new_agent.box.r0rfc0cf = [r0 rf c0 cf];
            new_agent.box.xywh     = [ x  y  w  h];
            new_agent.box.xcycwh   = [xc yc  w  h];
            new_agent.box.aspect_ratio = w/h;
            new_agent.box.area_ratio   = (w*h) / (im_size(1)*im_size(2));
            if isempty(new_agents), new_agents = new_agent; else new_agents(end+1) = new_agent; end
        end
        
    % add them in to the pool
    if isempty(agent_pool)
        agent_pool = new_agents;
    else
        agent_pool(end+1:end+length(new_agents)) = new_agents;
    end
    
end


