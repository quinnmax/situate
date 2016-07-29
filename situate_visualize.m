
function [h, return_status_string] = situate_visualize( h, im, p, d, workspace, cur_agent, population_count, scout_record, visualization_description )



% [h, return_status_string] = situate_visualize( h, im, p, d, workspace, cur_agent, population_count, scout_record, visualization_description );
%
% to initialize
%   [h, return_status_string] = situate_visualize( [], im, p, d, workspace, cur_agent, population_count, scout_record, visualization_description )
%
% to update
%   [h, return_status_string] = situate_visualize( h, im, p, d, workspace, cur_agent, population_count, scout_record, visualization_description )
%
% to draw a final visualization
%   [h, return_status_string] = situate_visualize( h, im, p, d, workspace, [], population_count, scout_record, visualization_description )

    

    %% get set up 
    % see if this is an initial drawing, 
    % see if the workspace has been updated
    
    min_frame_time = .1; % seconds
    
    global situate_visualizer_run_status;
    
    return_status_string = '';
    
    sp_cols = 3 + length(p.situation_objects); % number of columns in the subplot
    
    initial_figure_generation = false;
    workspace_has_updated = false;
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
        if  p.start_paused
            situate_visualizer_run_status = 'unstarted';
        else
            situate_visualizer_run_status = 'running';
        end
        UserData.workspace_support_total = 0;
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
        % see if the workspace has an imporved support total since last time we updated
        if sum(workspace.total_support) > UserData.workspace_support_total
            workspace_has_updated = true;
            UserData.workspace_support_total = sum( workspace.total_support);
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

    
    
    %% draw workspace (main image) 
    
        subplot2(3,sp_cols,1,1,2,3); 
        
        if initial_figure_generation
            UserData.workspace_im_handle = imshow( im ); 
            % else, it should already be up, no need to redraw
        end
        
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
        
        temp_h = title(UserData.workspace_im_handle.Parent,workspace_title);
        default_position = get(temp_h,'Position');
        set(temp_h,'Position', default_position - [0 10 0] );
        UserData.handles(end+1) = temp_h;
        UserData.workspace_im_handle.Parent.Title.Visible = 'on';
        set(h,'UserData',UserData);
        
        
       
    %% draw bottom left graph (something about the population) 
    % draw a population distribution or interest counts
    subplot2(3,sp_cols,3,1,3,3);
    plotting_subject = 'interest_iterations';
    switch plotting_subject
        case 'population_counts'
            plot([[population_count.scout];[population_count.reviewer];[population_count.builder]]');
            xlim([0 p.num_iterations]);
            xlabel('iteration'); 
            ylabel('population'); 
            legend({'scouts','reviewers','builders'},'Location','NorthEast');
        case 'interest_iterations'
            [value_counts] = counts( {scout_record.interest}, p.situation_objects );
            temp_h = bar( 1:length(p.situation_objects), value_counts );
            set( get(temp_h,'Parent'), 'XTickLabel', p.situation_objects );
            %temp_h.Parent.XTickLabel = p.situation_objects;
            if ~isempty(value_counts), ylim([0 max(value_counts) + 2]); else ylim([0 1]); end
            xlabel('category');
            ylabel('number of samples');
            yrange = max(value_counts) + 2;
            set( get( get( temp_h, 'Parent' ), 'Xlabel' ), 'Position',  [2 -.2 * yrange, -1] );
            % temp_h.Parent.XLabel.Position = [2 -.2 * yrange, -1];
    end
    
    
    
    %% draw the xy distributions 
        % only the distribution associated with the interest of the most
        % recent scout should have changed, so just draw that one if
        % possible
        
        if initial_figure_generation || workspace_has_updated || strcmp(situate_visualizer_run_status,'end')
            
            % do a full redraw of each distribution
            for oi = 1:length(d)
                subplot2(3,sp_cols,1,4+oi-1); 
                imshow(d(oi).location_display, []); 
                title([d(oi).interest ' location']);
            end
            
        end
       
        
        
    %% draw the box distributions 
   
    if initial_figure_generation || workspace_has_updated || strcmp(situate_visualizer_run_status,'end')
        
        for oi = 1:length(d)
            
            switch d(oi).box_display.method
                
                case 'plots'
                    
                    subplot2(3,sp_cols,2,3 + oi); 
                    h1_temp = plot(d(oi).box_display.x1,d(oi).box_display.y1);
                    h1 = get(h1_temp,'Parent');
                    
                    title_text = d(oi).interest;
                    title_text = {[title_text ' box'], 'distribution'};
                    title(title_text);

                    xlabel(d(oi).box_display.label1);
                    ylabel('density');
                    xlim_range = max(d(oi).box_display.x1) - min(d(oi).box_display.x1);
                    xlim_min = min(d(oi).box_display.x1) - .1 * xlim_range;
                    xlim_max = max(d(oi).box_display.x1) + .1 * xlim_range;
                    set(gca,'XLim',[xlim_min xlim_max]);
                    set(gca,'YLim',[0 max(d(oi).box_display.y1)*1.25]);
                    if datenum(version('-date'))>datenum('January 1, 2015')
                        set(gca,'YTickLabelRotation', 90);
                    end
                  
                    subplot2(3,sp_cols,3,3 + oi); 
                    h2_temp = plot(d(oi).box_display.x2,d(oi).box_display.y2);
                    h2 = h2_temp.Parent;
                    
                    xlabel(d(oi).box_display.label2);
                    ylabel('density');
                    xlim_range = max(d(oi).box_display.x2) - min(d(oi).box_display.x2);
                    xlim_min = min(d(oi).box_display.x2) - .1 * xlim_range;
                    xlim_max = max(d(oi).box_display.x2) + .1 * xlim_range;
                    set(gca,'XLim',[xlim_min xlim_max]);
                    set(gca,'YLim',[0 max(d(oi).box_display.y2)*1.25]);
                    if datenum(version('-date'))>datenum('January 1, 2015')
                        set(gca,'YTickLabelRotation', 90);
                    end
                    
                case 'map'
                    
                    subplot2(3,sp_cols,2,3+oi,3,3+oi); 
                    temp_h = imshow(d(oi).box_display.map,[]);
                    title({[d(oi).interest ' box'],'distribution'});

                    xlabel(d(oi).box_display.xlabel);
                    x_ticks = linspace(1,size(d(oi).box_display.map,2),5);
                    x_ticks = x_ticks(2:end-1);
                    x_tick_labels = {sprintf('%.2f\n',d(oi).box_display.xrange([.25 * end, .5*end, .75*end]))};
                    set(get(temp_h,'Parent'),'Visible','on');
                    set(get(temp_h,'Parent'),'XTick',x_ticks);
                    set(get(temp_h,'Parent'),'XTickLabel',x_tick_labels);

                    ylabel(d(oi).box_display.ylabel);
                    y_ticks = linspace(1,size(d(oi).box_display.map,1),5);
                    y_ticks = y_ticks(2:end-1);
                    y_tick_labels = {sprintf('%.2f\n',d(oi).box_display.yrange([.25 * end, .5*end, .75*end]))};
                    set(get(temp_h,'Parent'),'YTick',y_ticks);
                    set(get(temp_h,'Parent'),'YTickLabel',y_tick_labels);
                    if datenum(version('-date'))>datenum('January 1, 2015')
                        set(get(temp_h,'Parent'),'YTickLabelRotation', 90);
                    end
                    
                otherwise
                
                    warning('newmethodwarning','new method code goes here');
                    error('something something');
                    
                    subplot2(3,sp_cols,2,3+oi);
                    plot([0 1],[0 0]);
                    text(.5,0,'unimplemented');
                    subplot2(3,sp_cols,3,3+oi); 
                    plot([0 1],[0 0]);
                    text(.5,0,'unimplemented');
            end
            
            % manual display adjustments
            if any(strcmp(d(oi).box_display.method,{'plots','marginal'}))
           
                set(h1,'YTick',[]);
                set(h2,'YTick',[]);

                % resetting xlim for plots and marginals manually
                
                switch d(oi).box_method
                    
                    case {'conditional_mvn_log_aa','independent_uniform_log_aa','independent_normals_log_aa'}
                        set(h1,'XLim',[-3 3]);
                        set(h1,'XTick',[-2 0 2]);
                        set(h1,'XTickLabel',{'1:4', '1:1', '4:1'});
                        %h1.XLabel.String = {'aspect ratio','( width / height )'};
                        set(get(h1,'Xlabel'),'String',{'aspect ratio','( width / height )'});
                        
                        set(h2,'XLim',[-3.2 0]);
                        set(h2,'XTick',[-3 -2 -1 0]);
                        set(h2,'XTickLabel',{'.001', '.01', '.1', '1'});
                        %h2.XLabel.String = 'area ratio';
                        set(get(h2,'Xlabel'),'String','area ratio')
                        
                    case {'conditional_mvn_aa','independent_uniform_aa','independent_normals_aa'}
                        set(h1,'XLim',[0 5]);
                        set(h1,'XTick',[.25 1 4]);
                        set(h1,'XTickLabel',{'1:4', '1:1', '4:1'});
                        %h1.XLabel.String = {'aspect ratio','( width / height )'};
                        set(get(h1,'Xlabel'),'String',{'aspect ratio','( width / height )'})
                        
                        set(h2,'XLim',[0 1]);
                        set(h2,'XTick',[.05 .5 .95]);
                        set(h2,'XTickLabel',{'5%', '50%', '95%'});
                        %h2.XLabel.String = 'area ratio';
                        set(get(h2,'Xlabel'),'String','area ratio')
                        
                    case {'conditional_mvn_wh','independent_uniform_wh','independent_normals_wh'}
                        set(h1,'XLim',[0 1]);
                        set(h1,'XTick',[.25 .5 .75]);
                        set(h1,'XTickLabel',{'.25', '.50', '.75'});
                        %h1.XLabel.String = 'width';
                        set(get(h1,'Xlabel'),'String','width');
                        
                        set(h2,'XLim',[0 1]);
                        set(h2,'XTick',[.25 .5 .75]);
                        set(h2,'XTickLabel',{'.25', '.50', '.75'});
                        %h2.XLabel.String = 'height';
                        set(get(h2,'Xlabel'),'String','height');
                        
                    case {'conditional_mvn_log_wh','independent_uniform_log_wh','independent_normals_log_wh'}
                        set(h1,'XLim',[0 1]);
                        set(h1,'XTick',[-2.9957   -1.3863   -0.6931   -0.2877   0]);
                        set(h1,'XTickLabel',{'.05','.25','.5','1'});
                        %h1.XLabel.String = 'width';
                        set(get(h1,'Xlabel'),'String','width');
                        
                        set(h2,'XLim',[0 1]);
                        set(h2,'XTick',[-2.9957   -1.3863   -0.6931   -0.2877   0]);
                        set(h2,'XTickLabel',{'.05','.25','.5','1'});
                        %h2.XLabel.String = 'height';
                        set(get(h2,'Xlabel'),'String','height');
                     
                    otherwise
                        warning('newmethodwarning','new method code goes here');
                        
                end
                
            end
            
        end
        
    end
      
        
        
    %% draw representation of current scout onto distributions 
    
    if ~isempty(cur_agent) && isequal( cur_agent.type, 'scout' )
        
        di = find(strcmp(cur_agent.interest,p.situation_objects));
        if length(di) > 1, di = di(randi(length(di))); end
        
        % draw onto main figure
        subplot2(3,sp_cols,1,1,2,3); 
        hold on;
        UserData.handles(end+1) = draw_box(cur_agent.box.r0rfc0cf, 'r0rfc0cf', 'blue');
        hold off;

        label_text = [cur_agent.interest '?'];
        t1 = text( cur_agent.box.r0rfc0cf(3), cur_agent.box.r0rfc0cf(1), label_text);
        set(t1,'color',[0 0 0]);
        set(t1,'FontSize',14);
        set(t1,'FontWeight','bold');
        t2 = text( cur_agent.box.r0rfc0cf(3)+1, cur_agent.box.r0rfc0cf(1)+1, label_text);
        set(t2,'color',[1 1 1]);
        set(t2,'FontSize',14);
        set(t2,'FontWeight','bold');
        UserData.handles(end+1) = t1;
        UserData.handles(end+1) = t2;

        % draw onto location distribution maps
        subplot2(3,sp_cols,1,3+di);
        hold on
        temp_h = draw_box(cur_agent.box.r0rfc0cf, 'r0rfc0cf', 'blue');
        hold off;
        UserData.handles(end+1) = temp_h;

        % box distribution
        switch d(di).box_display.method

            case {'plots','marginal'}

                switch d(di).box_method
                    case {'independent_uniform_log_aa','independent_normals_log_aa','conditional_mvn_log_aa'}
                        x1_val = log2(cur_agent.box.aspect_ratio);
                        x2_val = log10(cur_agent.box.area_ratio);

                    case {'independent_uniform_aa','independent_normals_aa','conditional_mvn_aa'}
                        x1_val = cur_agent.box.aspect_ratio;
                        x2_val = cur_agent.box.area_ratio;

                    case {'independent_uniform_wh','independent_normals_wh','conditional_mvn_wh'}
                        x1_val = cur_agent.box.xywh(3);
                        x2_val = cur_agent.box.xywh(4);

                    case {'independent_uniform_log_wh','independent_normals_log_wh','conditional_mvn_log_wh'}
                        x1_val = log(cur_agent.box.xywh(3));
                        x2_val = log(cur_agent.box.xywh(4));

                    otherwise
                        error('unimplemented');
                end

                switch d(di).box_display.method
                    case 'plots'
                        [~,y1_val_ind] = min( abs( x1_val - d(di).box_display.x1) );
                        y1_val = d(di).box_display.y1(y1_val_ind);

                        [~,y2_val_ind] = min( abs( x2_val - d(di).box_display.x2 ) );
                        y2_val = d(di).box_display.y2(y2_val_ind);
                    case 'marginal'
                        [~,y1_val_ind] = min( abs( x1_val - d(di).box_display.xrange) );
                        y1_val = d(di).box_display.marginal_x(y1_val_ind);

                        [~,y2_val_ind] = min( abs( x2_val - d(di).box_display.yrange ) );
                        y2_val = d(di).box_display.marginal_y(y2_val_ind);
                end

                subplot2(3,sp_cols,2,3 + di);
                hold on;
                temp_h = plot( x1_val, y1_val, 'xb' );
                hold off;
                UserData.handles(end+1) = temp_h;

                subplot2(3,sp_cols,3,3 + di); 
                hold on;
                temp_h = plot( x2_val, y2_val, 'xb' );
                hold off;
                UserData.handles(end+1) = temp_h;

            case 'map'

                switch d(di).box_method
                    case 'conditional_mvn_log_aa'
                        x_val = log2(cur_agent.box.aspect_ratio);
                        y_val = log10(cur_agent.box.area_ratio);
                    case 'conditional_mvn_aa'
                        x_val = cur_agent.box.area_ratio;
                        y_val = cur_agent.box.aspect_ratio;
                    case 'conditional_mvn_log_wh'
                        x_val = log(cur_agent.box.xywh(3));
                        y_val = log(cur_agent.box.xywh(4));
                    case 'conditional_mvn_wh'
                        x_val = cur_agent.box.xywh(3);
                        y_val = cur_agent.box.xywh(4);
                    otherwise
                        error('unimplemented');
                end
                subplot2(3,sp_cols,2,3+di,3,3+di);
                hold on;
                temp_h = plot_onto_imshow( x_val, y_val, d(di).box_display.xrange, d(di).box_display.yrange, 'xb' );
                hold off;
                UserData.handles(end+1) = temp_h;

            otherwise
                subplot2(3,sp_cols,2,3 + di); 

        end

    end

    
    
    %% draw workspace information onto distributions 
    
        if ~isempty(workspace)
            
            point_format_final = 'or';
            point_format_provisional = 'xr';
            bounding_box_format_final = 'r';
            bounding_box_format_provisional = 'r--';

            subplot2(3,sp_cols,1,1,2,3); 

            % draw workspace boxes onto main image
            hold on;
            for wi = 1:size(workspace.boxes_r0rfc0cf,1)
                if workspace.internal_support(wi) >= p.thresholds.total_support_final
                    UserData.handles(end+1) = draw_box(workspace.boxes_r0rfc0cf(wi,:), 'r0rfc0cf', bounding_box_format_final);
                else
                    UserData.handles(end+1) = draw_box(workspace.boxes_r0rfc0cf(wi,:), 'r0rfc0cf', bounding_box_format_provisional);
                end
            end

            % then draw the text ( so boxes don't cover text )
            for wi = 1:size(workspace.boxes_r0rfc0cf,1)
                label_text = workspace.labels{wi};
                label_text = [label_text  ': ' sprintf( '%0.2f',workspace.internal_support(wi))];
                if ~isequal(p.classification_method,'IOU_oracle')
                    label_text_original = label_text;
                    label_text = cell(2,1);
                    label_text{1} = label_text_original;
                    label_text{2} = ['<gt iou: ' num2str(workspace.GT_IOU(wi)) '>'];
                end
                t1 = text( workspace.boxes_r0rfc0cf(wi,3), workspace.boxes_r0rfc0cf(wi,1), label_text);
                set(t1,'color',[0 0 0]);
                set(t1,'FontSize',14);
                set(t1,'FontWeight','bold');
                t2 = text( workspace.boxes_r0rfc0cf(wi,3)+1, workspace.boxes_r0rfc0cf(wi,1)+1, label_text);
                set(t2,'color',[1 1 1]);
                set(t2,'FontSize',14);
                set(t2,'FontWeight','bold');

                UserData.handles(end+1) = t1;
                UserData.handles(end+1) = t2;
            end
            hold off;

            % draw workspace stats onto distributions that generated them
            for wi = 1:size(workspace.boxes_r0rfc0cf,1)
                
                if workspace.total_support(wi) >= p.thresholds.total_support_final
                    point_format = point_format_final;
                    bounding_box_format = bounding_box_format_final;
                else
                    point_format = point_format_provisional;
                    bounding_box_format = bounding_box_format_provisional;
                end
                
                width  = workspace.boxes_r0rfc0cf(wi,4) - workspace.boxes_r0rfc0cf(wi,3) + 1;
                height = workspace.boxes_r0rfc0cf(wi,2) - workspace.boxes_r0rfc0cf(wi,1) + 1;
                width_ratio = width / sqrt(d(1).image_size_px);
                height_ratio = height / sqrt(d(1).image_size_px);
                aspect_ratio =  width / height;
                area_ratio   = (width * height) / d(1).image_size_px;
 
                oi = find(strcmp(workspace.labels{wi},p.situation_objects));
                if length(oi) > 1, oi = oi(randi(length(oi))); end
                
                switch d(oi).box_display.method

                    case 'plots'

                        switch d(oi).box_method
                            case {'independent_uniform_log_aa','independent_normals_log_aa','conditional_mvn_log_aa'}
                                x1_val = log2(aspect_ratio);
                                x2_val = log10(area_ratio);
                            case {'independent_uniform_aa','independent_normals_aa','conditional_mvn_aa'}
                                x1_val = aspect_ratio;
                                x2_val = area_ratio;
                            case {'independent_uniform_wh','independent_normals_wh','conditional_mvn_wh'}
                                x1_val = width_ratio;
                                x2_val = height_ratio;
                            case {'independent_uniform_log_wh','independent_normals_log_wh','conditional_mvn_log_wh'}
                                x1_val = log( width_ratio);
                                x2_val = log( height_ratio);
                            otherwise
                                error('unimplemented');
                        end

                        [~,y1_val_ind] = min( abs( x1_val - d(oi).box_display.x1) );
                        y1_val = d(oi).box_display.y1(y1_val_ind);

                        [~,y2_val_ind] = min( abs( x2_val - d(oi).box_display.x2 ) );
                        y2_val = d(oi).box_display.y2(y2_val_ind);
                       
                        subplot2(3,sp_cols,2,3 + oi);
                        hold on;
                        temp_h = plot( x1_val, y1_val, point_format );
                        hold off;
                        UserData.handles(end+1) = temp_h;

                        subplot2(3,sp_cols,3,3 + oi); 
                        hold on;
                        temp_h = plot( x2_val, y2_val, point_format );
                        hold off;
                        UserData.handles(end+1) = temp_h;

                    case 'map'

                        switch d(oi).box_method
                            case 'conditional_mvn_log_aa'
                                x_val = log2(aspect_ratio);
                                y_val = log10(area_ratio);
                            case 'conditional_mvn_aa'
                                x_val = area_ratio;
                                y_val = aspect_ratio;
                            case 'conditional_mvn_log_wh'
                                x_val = log(width_ratio);
                                y_val = log(height_ratio);
                            case 'conditional_mvn_wh'
                                x_val = log(width_ratio);
                                y_val = log(height_ratio);
                            otherwise
                                error('unimplemented');
                        end
                        subplot2(3,sp_cols,2,3+oi,3,3+oi);
                        hold on;
                        temp_h = plot_onto_imshow( x_val, y_val, d(oi).box_display.xrange, d(oi).box_display.yrange, point_format );
                        hold off;
                        UserData.handles(end+1) = temp_h;


                    otherwise
                        subplot2(3,sp_cols,2,3 + oi); 

                end
                
                % now draw any checked in boxes onto the 
                % location distribution maps
                
                subplot2(3,sp_cols,1,3+oi);
                hold on
                temp_h = draw_box(workspace.boxes_r0rfc0cf(wi,:), 'r0rfc0cf', bounding_box_format);
                hold off;
                UserData.handles(end+1) = temp_h;
                
            end
        end
        
    set(h,'UserData',UserData);
       
    
    
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
        % if the user killed it while we were drawing
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
                if ishandle(h), 
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


