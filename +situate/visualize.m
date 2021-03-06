


function [h, return_status_string] = visualize( h, im, p, d, workspace, cur_agent, agent_pool, scout_record, visualization_description )
% [h, return_status_string] = visualize( h, im, p, d, workspace, cur_agent, agent_pool, scout_record, visualization_description ); 
%
% to initialize
%   [h, return_status_string] = situate.visualize( [], im, p, d, workspace, cur_agent, agent_pool, scout_record, visualization_description, agent_pool )
%
% to update
%   [h, return_status_string] = situate.visualize( h, im, p, d, workspace, cur_agent, agent_pool, scout_record, visualization_description, agent_pool )
%
% to draw a final visualization
%   [h, return_status_string] = situate.visualize( h, im, p, d, workspace, [], agent_pool, scout_record, visualization_description )

    

%% get set up 
    % see if this is an initial drawing, 
    % see if the workspace has been updated
    
    font_size = 12;
    
    min_frame_time = .001; % seconds
    
    global situate_visualizer_run_status;
    
    return_status_string = '';
    
    point_format_final              = 'or';
    point_format_provisional        = 'xr';

    bounding_box_format_final       = 'r';
    bounding_box_format_provisional = 'r--';
    
    sp_cols = 4 + length(p.situation_objects); % number of columns in the subplot
    
    initial_figure_generation = false;
    if ~exist('h','var') || isempty(h)
        
        initial_figure_generation = true;
        h = figure();
        
        screen_size = get(groot,'ScreenSize');
        fig_height = 700;
        fig_width  = 1100;
        set( h, 'OuterPosition', [ 1 1 fig_width fig_height ]);
        set( h, 'OuterPosition', [ 20 (screen_size(4)-fig_height-24-20) fig_width fig_height ]);
        set(0,'defaultLineLineWidth', 2)
        UserData = [];
        if p.viz_options.start_paused
            situate_visualizer_run_status = 'unstarted';
        else
            situate_visualizer_run_status = 'running';
        end
        UserData.workspace_support_total = 0;
        if isfield(workspace, 'temperature')
            UserData.workspace_temperature = workspace.temperature;
        end
        tic;
        UserData.last_draw_time = toc;
    else
        if gcf ~= h, figure(h); end
        % remove any of the existing plots, dots, boxes so we can avoid
        % redrawing with imshow (which is more expensive)
        UserData = get(h,'UserData');
        for i = 1:length(UserData.handles)
            delete(UserData.handles(i));
        end
        % see if the workspace or temperature have changed since we last updated
        if sum(workspace.total_support) ~= UserData.workspace_support_total ...
        || (isfield(UserData,'workspace_temperature') && UserData.workspace_temperature ~= workspace.temperature)
            UserData.workspace_support_total = sum( workspace.total_support);
            UserData.workspace_temperature = workspace.temperature;
        end
    end
    UserData.handles = [];
    
    if any(strcmp(situate_visualizer_run_status,{'restart','next_image','end'}))
        % if we exited with one of these in user data, we should have
        % returned it in the return_string_status and the GUI loop should
        % have been killed.
        error('we should''t get here');
    end
        
    if isempty(cur_agent) && ~isempty(workspace.boxes_r0rfc0cf)
        % if we have no most recent agent, but do have a real workspace,
        % then we're probably looking at a final display
        situate_visualizer_run_status = 'end';
    end
    
    set(h,'UserData',UserData);
    
    
    
%% draw workspace (main image and found objects) 
    
        subplot2(3,sp_cols,1,1,2,3); 
        
        if initial_figure_generation
            UserData.workspace_im_handle = imshow( im ); 
        end
        
        % workspace description: multiline, single, or missing
        if exist('visualization_description','var')    ...
        && ~isempty(visualization_description)
            if iscell(visualization_description)
                workspace_title = ['Workspace'; visualization_description];
            else
                workspace_title = {'Workspace'; visualization_description};
            end
        else
            workspace_title = 'Workspace';
        end
        
        % move workspace title manually
        temp_h = title(UserData.workspace_im_handle.Parent,workspace_title);
        default_position = get(temp_h,'Position');
        set(temp_h,'Position', default_position - [0 10 0] );
        UserData.handles(end+1) = temp_h;
        UserData.workspace_im_handle.Parent.Title.Visible = 'on';
        set(h,'UserData',UserData);
        
        % draw the workspace entries on the workspace image
        temp_h = situate.workspace_draw( [], p, workspace, font_size );
        UserData.handles(end+1:end+length(temp_h)) = temp_h;
     
        % draw the current agent on the workspace image
        skip_this_agent = false;
        if isempty(cur_agent) ...
        || (~isempty(workspace.boxes_r0rfc0cf) ...
            && any(logical(prod(eq( repmat(cur_agent.box.r0rfc0cf,size(workspace.boxes_r0rfc0cf,1),1), workspace.boxes_r0rfc0cf),2))) )
            skip_this_agent = true;
        end
        
        if ~skip_this_agent
            
            switch cur_agent.history
                case 'blank'
                    box_color = 'black';
                case 'primedRCNN'
                    box_color = 'yellow';
                case {'primedRCNN_boxAdjust', 'blank_boxAdjust'}
                    box_color = 'green';
                otherwise
                    box_color = 'blue';
                    %error('dont recognize history');
            end
            
            hold on;
            UserData.handles(end+1) = draw_box(cur_agent.box.r0rfc0cf, 'r0rfc0cf', box_color);
            hold off;
            
            label_text = {...
                [cur_agent.interest '?']; ...
                % ['  internal: ' num2str(cur_agent.support.internal)]; ...
                % ['  external: ' num2str(cur_agent.support.external)]; ...   % this should be NaN at scout level anayway
                % ['  total:    ' num2str(cur_agent.support.total)]; ...      % this should be NaN at scout level anayway
                % ['  gt:       ' num2str(cur_agent.support.GROUND_TRUTH)] ...
            };
            if isfield(cur_agent.support, 'logistic_regression_data')
                display('does this exist anymore?');
                assert(1==0);
                label_text{end+1} = ['  coeff:    ' num2str(cur_agent.support.logistic_regression_data.coefficients)];
                label_text{end+1} = ['  external: ' num2str(cur_agent.support.logistic_regression_data.external)];
            end
            t1 = text( double(cur_agent.box.r0rfc0cf(3)), double(cur_agent.box.r0rfc0cf(1)), label_text);
            set(t1,'color',[0 0 0]);
            set(t1,'FontSize',font_size);
            set(t1,'FontWeight','bold');
            t2 = text( double(cur_agent.box.r0rfc0cf(3)+1), double(cur_agent.box.r0rfc0cf(1)+1), label_text);
            set(t2,'color',[1 1 1]);
            set(t2,'FontSize',font_size);
            set(t2,'FontWeight','bold');
            UserData.handles(end+1) = t1;
            UserData.handles(end+1) = t2;
        end
        
        
       
%% draw bottom left graph (something about the population) 
    
    % draw a population distribution or interest counts
    subplot2(3,sp_cols,3,1,3,3);
    %plotting_subject = 'interest_iterations';
    plotting_subject = 'internal_support_dists';
   
    switch plotting_subject
        
        case 'population_counts'
            
            plot([[population_count.scout];[population_count.reviewer];[population_count.builder]]');
            xlim([0 p.num_iterations]);
            xlabel('iteration'); 
            ylabel('population'); 
            legend({'scouts','reviewers','builders'},'Location','NorthEast');
            
        case 'interest_iterations'
            
            value_counts = zeros(1,length(p.situation_objects));
            for oi = 1:length(p.situation_objects)
                value_counts(oi) = sum( eq( oi, [scout_record.interest] ) );
            end
            %[value_counts] = counts( {scout_record.interest}, p.situation_objects );
            temp_h = bar( 1:length(p.situation_objects), value_counts );
            
            interest_priorities = {d.interest_priority};
            interest_priorities = interest_priorities(1:end-1);
            xtic_labels = cellfun( @(x,y) [x ': ' num2str(y)], p.situation_objects, interest_priorities, 'UniformOutput', false );
            
            set( get( temp_h, 'Parent' ), 'XTickLabel', xtic_labels );
            if ~isempty(value_counts), ylim([0 max(value_counts) + 2]); else ylim([0 1]); end
            xlabel('category');
            ylabel('number of samples');
            yrange = max(value_counts) + 2;
            set( get( get( temp_h, 'Parent' ), 'Xlabel' ), 'Position',  [2 -.2 * yrange, -1] );
            
        case 'internal_support_dists'
            
            has_interest = ~cellfun( @isempty, {agent_pool.interest} );
            urgencies = [agent_pool.urgency];
            
            x = linspace(.1,.9,5);
            
            m = hist(urgencies(has_interest),x);
            n = hist(urgencies(~has_interest),x);
            
            subplot2(3,sp_cols,3,1,3,1);
            % urgency of agents with an interest
            stem(x,m);
            xlim([-.1 1.1]);
            ylim([0 1 + 1.1 * max([m n])]);
            title('urgencies assigned');
            
            subplot2(3,sp_cols,3,2,3,2);
            % urgency of agents without an interest
            stem(x,n);
            xlim([-.1 1.1]);
            ylim([0 1 + 1.1 * max([m n])]);
            title('urgencies unassigned');
            
            subplot2(3,sp_cols,3,3,3,3);
            % dist of histories
            [num_each_history, unique_histories] = counts( {agent_pool.history} );
            h_temp = bar( 1:length(unique_histories), num_each_history );
            h_temp.Parent.XTickLabel = unique_histories;
            h_temp.Parent.XTickLabelRotation = 30;
            xlim([0 max(3,length(unique_histories)+1)]);
            title('history dist');
            
    end
    
    
        
%% draw the box distributions 
   
    for oi = 1:length(p.situation_objects)
        
        samples_represented = [];
        samples_represented_formatting_box   = {};
        samples_represented_formatting_point = {};
        
        % represent the workspace entries
        owi = strcmp( workspace.labels, p.situation_objects{oi}); % object workspace indices
        if any( owi )
            % add box to boxes_represented with appropriate formatting
            samples_represented(end+1,:) = workspace.boxes_r0rfc0cf(owi,:);
            if workspace.total_support(owi) >= p.thresholds.total_support_final
                samples_represented_formatting_box{end+1}   = bounding_box_format_final;
                samples_represented_formatting_point{end+1} = point_format_final;
            else
                samples_represented_formatting_box{end+1}   = bounding_box_format_provisional;
                samples_represented_formatting_point{end+1} = point_format_provisional;
            end
        end
        
        % add the current agent to the list of samples to represent
        internal_string = '';
        external_string = '';
        total_string = '';
        gt_string = '';
        if ~isempty(cur_agent) && isequal( cur_agent.interest, p.situation_objects{oi} )
            
            % add box to boxes_respresented with appropriate formatting
            samples_represented(end+1,:) = cur_agent.box.r0rfc0cf;
            samples_represented_formatting_box{end+1}   = '-b';
            samples_represented_formatting_point{end+1} = 'ob';
            
            internal_string = ['int: ' sprintf('%0.4f', cur_agent.support.internal) ];
            external_string = ['ext: ' sprintf('%0.4f', cur_agent.support.external) ];
            total_string    = ['tot: ' sprintf('%0.4f', cur_agent.support.total)    ];
            gt_string       = ['gt:  ' sprintf('%0.4f', cur_agent.support.GROUND_TRUTH) ];
            
        end
        
        subplot2(3,sp_cols,1,5+oi-1); 
        temp_h = p.situation_model.draw( d, p.situation_objects{oi}, 'xy', samples_represented, samples_represented_formatting_box, initial_figure_generation );    
        title({[d(oi).interest ' location'];internal_string;external_string;total_string;gt_string});
        UserData.handles(end+1:end+length(temp_h)) = temp_h;
    
        subplot2(3,sp_cols,2,5+oi-1); 
        temp_h = p.situation_model.draw( d, p.situation_objects{oi}, 'shape', samples_represented, samples_represented_formatting_point, false );
        title([d(oi).interest ' box shape']);
        UserData.handles(end+1:end+length(temp_h)) = temp_h;
    
        subplot2(3,sp_cols,3,5+oi-1); 
        temp_h = p.situation_model.draw( d, p.situation_objects{oi}, 'size',  samples_represented, samples_represented_formatting_point, false );
        title([d(oi).interest ' box size']);
        UserData.handles(end+1:end+length(temp_h)) = temp_h;
    
    end
    
   
      
%% start, stop, step buttons 

    if initial_figure_generation
            
        m = 4; % number of buttons
        button_width = 100;
        button_height = 25;
        step = button_width + 10; % pixels between entry

        fig_dimensions = get(h,'Position');
        fig_width = fig_dimensions(3);
        positions = repmat([ fig_width 15 button_width button_height  ],m,1) - [ step*(m:-1:1)' zeros(m,1)  zeros(m,1) zeros(m,1) ];

        btn_handles = [];
        
        cur_position_ind = 1;
        btn_handles.btn_start_restart = uicontrol(...
            'Style', 'pushbutton', ...
            'String', 'Start',...
            'Position', positions(cur_position_ind,:),...
            'Callback', {@callback_btn_start_restart, h, btn_handles} ); 
        
        cur_position_ind = 2;
        btn_handles.btn_pause_resume = uicontrol(...
            'Style', 'pushbutton', ...
            'String', 'Pause',...
            'Position', positions(cur_position_ind,:),...
            'Callback', {@callback_btn_pause_resume, h, btn_handles} );  

        cur_position_ind = 3;
        btn_handles.btn_step = uicontrol(...
            'Style', 'pushbutton', ...
            'String', 'Step',...
            'Position', positions(cur_position_ind,:),...
            'Callback', {@callback_btn_step, h, btn_handles} ); 
        
        cur_position_ind = 4;
        btn_handles.btn_next = uicontrol(...
            'Style', 'pushbutton', ...
            'String', 'Next image',...
            'Position', positions(cur_position_ind,:),...
            'Callback', {@callback_btn_next, h, btn_handles} ); 
        
    end

    
    
    % burn some time to set a consistent visualizer update rate
    if toc - UserData.last_draw_time < min_frame_time
        pause( min_frame_time - (toc - UserData.last_draw_time) );
    end
    
    
    % % % % % % % % % % 
    drawnow
    % % % % % % % % % % 
    
    
    % after drawing the update, we wait for a user input to continue
    
    if ~ishandle(h)
        % if the user closed the visualization while it was being rendered
        return_status_string = 'stop';
    else
        UserData.last_draw_time = toc;
        set(h,'UserData',UserData); % for the toc
        switch situate_visualizer_run_status
            case {'unstarted','paused','stepping','end'}
                set(h,'UserData',UserData);
                uiwait(h); 
                % we're waiting on a button press, possibely a callback, 
                % which might change the user data in h, so we need to grab
                % that as soon as we know it still exists
                if ishandle(h)
                    if any(strcmp( situate_visualizer_run_status, {'restart','next_image'} ))
                        return_status_string = situate_visualizer_run_status;
                    else
                        return_status_string = situate_visualizer_run_status;
                    end
                else
                    return_status_string = 'stop';
                end
            case {'running'}
                % do nothing, don't stop, just return
                return_status_string = situate_visualizer_run_status;
            case {'restart'}
                return_status_string = 'restart';
            case {'next_image'}
                return_status_string = 'next_image';
            otherwise
                error(['unrecognized global situate_visualizer_run_status was: ' situate_visualizer_run_status]);
        end
        
    end
    
   
    
end



function callback_btn_start_restart( source, callbackdata, h, btn_handles )

    global situate_visualizer_run_status

    switch situate_visualizer_run_status
        case 'unstarted'
            source.String = 'Restart';
            situate_visualizer_run_status = 'running';
            uiresume(h);
        case {'stepping','running','paused','end','restart'}
            uiresume(h);
            situate_visualizer_run_status = 'restart';
        otherwise
            error(['unrecognized global situate_visualizer_run_status was: ' situate_visualizer_run_status]);
    end
    
end

function callback_btn_pause_resume( source, callbackdata, h, btn_handles )
   
    global situate_visualizer_run_status

    switch situate_visualizer_run_status
        case 'running'
            source.String = 'Resume';
            btn_handles.btn_start_restart.String = 'Restart';
            situate_visualizer_run_status = 'paused';
        case 'paused'
            source.String = 'Pause';
            btn_handles.btn_start_restart.String = 'Restart';
            situate_visualizer_run_status = 'running';
            uiresume(h);
        case 'stepping'
            source.String = 'Pause';
            btn_handles.btn_start_restart.String = 'Restart';
            situate_visualizer_run_status = 'running';
            uiresume(h);
         case {'unstarted','end'}
            % nothing
         otherwise
            error(['unrecognized global situate_visualizer_run_status was: ' situate_visualizer_run_status]);
    end
    

end
   
function callback_btn_step( source, callbackdata, h, btn_handles )

    global situate_visualizer_run_status;

    switch situate_visualizer_run_status
        case 'running'
            btn_handles.btn_pause_resume.String = 'Resume';
            btn_handles.btn_start_restart.String = 'Restart';
            situate_visualizer_run_status = 'paused';
            uiwait(h);
        case 'paused'
            btn_handles.btn_pause_resume.String = 'Resume';
            btn_handles.btn_start_restart.String = 'Restart';
            situate_visualizer_run_status = 'stepping';
            uiresume(h);
        case 'stepping'
            btn_handles.btn_pause_resume.String = 'Resume';
            btn_handles.btn_start_restart.String = 'Restart';
            situate_visualizer_run_status = 'stepping';
            uiresume(h);
        case 'unstarted'
            btn_handles.btn_pause_resume.String = 'Resume';
            btn_handles.btn_start_restart.String = 'Restart';
            situate_visualizer_run_status = 'stepping';
            uiresume(h);
        case {'end'}
            % nothing
        otherwise
            error(['unrecognized global situate_visualizer_run_status was: ' situate_visualizer_run_status]);
    end
    
 
end

function callback_btn_next( source, callbackdata, h, btn_handles )

    global situate_visualizer_run_status;
    situate_visualizer_run_status = 'next_image';
    uiresume(h);
    
end


