
% load cnn data

    fn = '/Users/Max/Desktop/cnn_features_and_IOUs2017.07.23.16.50.08.mat';
    load(fn);
    
    num_situation_objects = length(p.situation_objects);
    num_crops = size(box_proposals_r0rfc0cf,1);

    
    
   


% setup

    split_file_directory = 'split_validation/'; % validation set (hard)
    
    dir_data        = dir( fullfile(split_file_directory, '*_fnames_split_1_train.txt') );
    fname_list_file = fullfile( split_file_directory, dir_data.name );
    fnames_train    = importdata( fname_list_file, '\n' );
    
    dir_data        = dir( fullfile(split_file_directory, '*_fnames_split_1_test.txt') );
    fname_list_file = fullfile( split_file_directory, dir_data.name );
    fnames_test     = importdata( fname_list_file, '\n' );
    
    fnames = vertcat(fnames_train,fnames_test);
    
    classifier.load  = @classifiers.IOU_ridge_regression_train;
    classifier.apply = @classifiers.IOU_ridge_regression_apply;
    classifier.saved_models_directory = 'default_models/';
    classifier.data = classifier.load( p, fnames, classifier.saved_models_directory );
    
    % external and total support functions as they exist
    activation_function = @(x,b) b(1) + b(2) * atan( b(3) * (x-b(4)) );
    b = [ 0.0237, 0.6106, 4.4710e-12, -0.3192 ];
    external_support_function = @(x) activation_function(x,b);
    
    b = [   0.0441    0.8744    0.0256    0.0068; ...
           -0.0227    0.9646    0.0517    0.0073; ...
            0.0319    0.5971    0.2638    0.0047 ];
    total_support_function    = {};
    total_support_function{1} = @(internal,external) b(1,1) + b(1,2) * internal + b(1,3) * external + b(1,4) * internal * external;
    total_support_function{2} = @(internal,external) b(2,1) + b(2,2) * internal + b(2,3) * external + b(2,4) * internal * external;
    total_support_function{3} = @(internal,external) b(3,1) + b(3,2) * internal + b(3,3) * external + b(3,4) * internal * external;
    
    total_support_threshold = .5625;
  
% get estimated IOU from classifier
    
    internal_support = nan( num_crops, 1 );
    for i = 1:num_crops
        obj_type = box_source_obj_type(i);
        cnn_features = box_proposal_cnn_features(i,:);
        internal_support(i) = [1 cnn_features] * classifier.data.models{ obj_type };
        if mod(i,1000)==0, progress(i,num_crops);end
    end
    
    figure;
    for oi = 1:num_situation_objects
        display_ratio = .05;
        cur_inds = eq( oi, box_source_obj_type );
        cur_inds = cur_inds & rand(size(cur_inds))<display_ratio;
        
        subplot(1,num_situation_objects,oi)
        plot( box_proposal_gt_IOUs(cur_inds), internal_support(cur_inds),'.');
        ylim([-.2,1.2]);
        xlabel('gt iou');
        ylabel('internal support');
        title(p.situation_objects{oi});
    end
    
    
    
%% visualize external support

    for oi = 1:num_situation_objects
        
        display_ratio = .05;
        cur_inds = eq( oi, box_source_obj_type );
        cur_inds = cur_inds & rand(size(cur_inds))<display_ratio;
        
        a = external_support_function( box_density_prior(cur_inds) );
        b = external_support_function( box_density_conditioned_1a(cur_inds) );
        c = external_support_function( box_density_conditioned_1b(cur_inds) );
        d = external_support_function( box_density_conditioned_2(cur_inds) );
        
        figure;
        plotmatrix([a,b,c,d]);
        title(p.situation_objects{oi});
        xlabel({'prior','conditioned 1a','conditioned 1b','conditioned 2'});
        
    end
       
    
 
%% learn total support function

    
    use_mixing = false;
    
    if use_mixing
        total_support_func = @(internal, external, oi, b) b(oi,1) + b(oi,2) * internal + b(oi,3) * external + b(oi,4) * internal .* external;
        num_weights = 4;
    else
        total_support_func = @(internal, external, oi, b) b(oi,1) + b(oi,2) * internal + b(oi,3) * external;
        num_weights = 3;
    end
    
%     b_prior = zeros( num_situation_objects, num_weights);
%     for oi = 1:num_situation_objects
%         cur_box_inds = eq( oi, box_source_obj_type );
%         internal_support_cur = internal_support(cur_box_inds);
%         external_support_cur = external_support_function( box_density_prior( cur_box_inds ) );
%         if use_mixing
%             x = [internal_support_cur, external_support_cur, internal_support_cur .* external_support_cur];
%         else
%             x = [internal_support_cur, external_support_cur ];
%         end
%         y = box_proposal_gt_IOUs(cur_box_inds);
%         k = 1000;
%         b_prior(oi,:) = ridge( y, x, k, 0 );
%     end
%     
%     b_conditioned_1a = zeros( num_situation_objects, num_weights);
%     for oi = 1:num_situation_objects
%         cur_box_inds = eq( oi, box_source_obj_type );
%         internal_support_cur = internal_support(cur_box_inds);
%         external_support_cur = external_support_function( box_density_conditioned_1a( cur_box_inds ) );
%         if use_mixing
%             x = [internal_support_cur, external_support_cur, internal_support_cur .* external_support_cur];
%         else
%             x = [internal_support_cur, external_support_cur ];
%         end
%         y = box_proposal_gt_IOUs(cur_box_inds);
%         k = 1000;
%         b_conditioned_1a(oi,:) = ridge( y, x, k, 0 );
%     end
%     
%     b_conditioned_1b = zeros( num_situation_objects, num_weights);
%     for oi = 1:num_situation_objects
%         cur_box_inds = eq( oi, box_source_obj_type );
%         internal_support_cur = internal_support(cur_box_inds);
%         external_support_cur = external_support_function( box_density_conditioned_1b( cur_box_inds ) );
%         if use_mixing
%             x = [internal_support_cur, external_support_cur, internal_support_cur .* external_support_cur];
%         else
%             x = [internal_support_cur, external_support_cur ];
%         end
%         y = box_proposal_gt_IOUs(cur_box_inds);
%         k = 1000;
%         b_conditioned_1b(oi,:) = ridge( y, x, k, 0 );
%     end
%     
%     b_conditioned_2 = zeros( num_situation_objects, num_weights);
%     for oi = 1:num_situation_objects
%         cur_box_inds = eq( oi, box_source_obj_type );
%         internal_support_cur = internal_support(cur_box_inds);
%         external_support_cur = external_support_function( box_density_conditioned_2( cur_box_inds ) );
%         if use_mixing
%             x = [internal_support_cur, external_support_cur, internal_support_cur .* external_support_cur];
%         else
%             x = [internal_support_cur, external_support_cur ];
%         end
%         y = box_proposal_gt_IOUs(cur_box_inds);
%         k = 1000;
%         b_conditioned_2(oi,:) = ridge( y, x, k, 0 );
%     end
%    
%     % try logistic regression for >.5 iou
%     b_mnr_prior = zeros( num_situation_objects, num_weights);
%     for oi = 1:num_situation_objects
%         cur_box_inds = eq( oi, box_source_obj_type );
%         internal_support_cur = internal_support(cur_box_inds);
%         external_support_cur = external_support_function( box_density_prior( cur_box_inds ) );
%         
%         if use_mixing
%             x = [internal_support_cur, external_support_cur, internal_support_cur .* external_support_cur];
%         else
%             x = [internal_support_cur, external_support_cur ];
%         end
%         y = ge( box_proposal_gt_IOUs(cur_box_inds), .5 ) + 1;
%         b_mnr_prior(oi,:) = mnrfit( x, y );
%         
%     end
%     
%     % try logistic regression for >.5 iou
%     b_mnr_conditioned_2 = zeros( num_situation_objects, num_weights);
%     for oi = 1:num_situation_objects
%         cur_box_inds = eq( oi, box_source_obj_type );
%         internal_support_cur = internal_support(cur_box_inds);
%         external_support_cur = external_support_function( box_density_prior( cur_box_inds ) );
%         
%         if use_mixing
%             x = [internal_support_cur, external_support_cur, internal_support_cur .* external_support_cur];
%         else
%             x = [internal_support_cur, external_support_cur ];
%         end
%         y = ge( box_proposal_gt_IOUs(cur_box_inds), .5 ) + 1;
%         b_mnr_conditioned_2(oi,:) = mnrfit( x, y );
%         
%     end
    

    % try a big jumble
    b_conditioned_combo = zeros( num_situation_objects, num_weights);
    for oi = 1:num_situation_objects
        cur_box_inds = eq( oi, box_source_obj_type );
        internal_support_cur = internal_support(cur_box_inds);
        internal_support_cur = repmat(internal_support_cur,4,1);
        external_support_cur_0  = external_support_function( box_density_prior( cur_box_inds ) );
        external_support_cur_1a = external_support_function( box_density_conditioned_1a( cur_box_inds ) );
        external_support_cur_1b = external_support_function( box_density_conditioned_1b( cur_box_inds ) );
        external_support_cur_2  = external_support_function( box_density_conditioned_2(  cur_box_inds ) );
        external_support_cur = [external_support_cur_0;external_support_cur_1a;external_support_cur_1b;external_support_cur_2];
        if use_mixing
            x = [internal_support_cur, external_support_cur, internal_support_cur.*external_support_cur];
        else
            x = [internal_support_cur, external_support_cur];
        end
        y = repmat( box_proposal_gt_IOUs(cur_box_inds), 4, 1 );
        %y = box_proposal_gt_IOUs(cur_box_inds);
        k = 1000;
        b_conditioned_combo(oi,:) = ridge( y, x, k, 0 );
    end
    
    figure
    for oi = 1:num_situation_objects
        cur_box_inds = eq( oi, box_source_obj_type );
        internal_support_cur = internal_support(cur_box_inds);
        internal_support_cur = repmat(internal_support_cur,4,1);
        external_support_cur_0  = external_support_function( box_density_prior( cur_box_inds ) );
        external_support_cur_1a = external_support_function( box_density_conditioned_1a( cur_box_inds ) );
        external_support_cur_1b = external_support_function( box_density_conditioned_1b( cur_box_inds ) );
        external_support_cur_2  = external_support_function( box_density_conditioned_2(  cur_box_inds ) );
        external_support_cur = [external_support_cur_0;external_support_cur_1a;external_support_cur_1b;external_support_cur_2];
        if use_mixing
            x = [internal_support_cur, external_support_cur, internal_support_cur.*external_support_cur];
        else
            x = [internal_support_cur, external_support_cur];
        end
        a = repmat( box_proposal_gt_IOUs(cur_box_inds), 4, 1 );
        b = total_support_func( internal_support_cur, external_support_cur, oi, b_conditioned_combo );
        
        cc = corrcoef(a,b);
        subplot2(1,num_situation_objects,1,oi);
        plot(a,b,'.');
        xlabel('gt iou');
        if oi == 1, ylabel({'mixed conditioning';'estimated iou'}); else, ylabel('estimated iou'); end
        legend(['cc: ' num2str(cc(1,2))],'location','southeast');
    end
    
   
    
    
    
   
    


%% see how the different estimates look

    figure();
    
    num_methods = 7;
    
    % internal
    for oi = 1:num_situation_objects
        subplot2(num_methods,num_situation_objects,1,oi);
        obj_inds = eq(oi,box_source_obj_type);
        a = box_proposal_gt_IOUs(obj_inds);
        b = internal_support(obj_inds);
        cc = corrcoef(a,b);
        plot(a,b,'.');
        xlabel('gt iou');
        if oi == 1, ylabel({'internal';'estimated iou'}); else, ylabel('estimated iou'); end
        title(p.situation_objects{oi});
        legend(['cc: ' num2str(cc(1,2))],'location','southeast');
    end
    
    % total prior
    for oi = 1:num_situation_objects
        subplot2(num_methods,num_situation_objects,2,oi);
        obj_inds = eq(oi,box_source_obj_type);

        a = box_proposal_gt_IOUs(obj_inds);
        internal = internal_support(obj_inds);
        external = external_support_function( box_density_prior( obj_inds ));
        b = total_support_func(internal, external, oi, b_prior);
        
        cc = corrcoef(a,b);
        plot(a,b,'.');
        xlabel('gt iou');
        if oi == 1, ylabel({'prior';'estimated iou'}); else, ylabel('estimated iou'); end
        legend(['cc: ' num2str(cc(1,2))],'location','southeast');
    end
    
    % total conditioned 1a
    for oi = 1:num_situation_objects
        subplot2(num_methods,num_situation_objects,3,oi);
        obj_inds = eq(oi,box_source_obj_type);
        
        a = box_proposal_gt_IOUs(obj_inds);
        internal = internal_support(obj_inds);
        external = external_support_function( box_density_conditioned_1a( obj_inds ));
        b = total_support_func(internal, external, oi, b_conditioned_1a);
        
        cc = corrcoef(a,b);
        plot(a,b,'.');
        xlabel('gt iou');
        if oi == 1, ylabel({'conditioned 1a';'estimated iou'}); else, ylabel('estimated iou'); end
        legend(['cc: ' num2str(cc(1,2))],'location','southeast');
    end
    
    % total conditioned 1b
    for oi = 1:num_situation_objects
        subplot2(num_methods,num_situation_objects,4,oi);
        obj_inds = eq(oi,box_source_obj_type);
        
        a = box_proposal_gt_IOUs(obj_inds);
        internal = internal_support(obj_inds);
        external = external_support_function( box_density_conditioned_1b( obj_inds ));
        b = total_support_func(internal, external, oi, b_conditioned_1b);
        
        cc = corrcoef(a,b);
        plot(a,b,'.');
        xlabel('gt iou');
        if oi == 1, ylabel({'conditioned 1b';'estimated iou'}); else, ylabel('estimated iou'); end
        legend(['cc: ' num2str(cc(1,2))],'location','southeast');
    end
    
    % total conditioned 2
    for oi = 1:num_situation_objects
        subplot2(num_methods,num_situation_objects,5,oi);
        obj_inds = eq(oi,box_source_obj_type);
        
        a = box_proposal_gt_IOUs(obj_inds);
        internal = internal_support(obj_inds);
        external = external_support_function( box_density_conditioned_2( obj_inds ));
        b = total_support_func(internal, external, oi, b_conditioned_2);
        
        cc = corrcoef(a,b);
        plot(a,b,'.');
        xlabel('gt iou');
        if oi == 1, ylabel({'conditioned 2';'estimated iou'}); else, ylabel('estimated iou'); end
        legend(['cc: ' num2str(cc(1,2))],'location','southeast');
    end
    
    % mnr prior
    for oi = 1:num_situation_objects
        subplot2(num_methods,num_situation_objects,6,oi);
        obj_inds = eq(oi,box_source_obj_type);
        
        a = box_proposal_gt_IOUs(obj_inds);
        internal = internal_support(obj_inds);
        external = external_support_function( box_density_prior( obj_inds ));
        
        if use_mixing
            b = mnrval(b_mnr_prior(oi,:)', [internal, external, internal.*external] );
            b = b(:,2);
        else
            b = mnrval(b_mnr_prior(oi,:)', [internal, external] );
            b = b(:,2);
        end
        
        cc = corrcoef(a,b);
        plot(a,b,'.');
        xlabel('gt iou');
        if oi == 1, ylabel({'mnr with prior density';'est P(iou > .5)'}); else, ylabel('est P(iou > .5)'); end
        legend(['cc: ' num2str(cc(1,2))],'location','southeast');
    end
    
    % mnr conditioned 2
    for oi = 1:num_situation_objects
        subplot2(num_methods,num_situation_objects,7,oi);
        obj_inds = eq(oi,box_source_obj_type);
        
        a = box_proposal_gt_IOUs(obj_inds);
        internal = internal_support(obj_inds);
        external = external_support_function( box_density_prior( obj_inds ));
        
        if use_mixing
            b = mnrval(b_mnr_conditioned_2(oi,:)', [internal, external, internal.*external] );
            b = b(:,2);
        else
            b = mnrval(b_mnr_conditioned_2(oi,:)', [internal, external] );
            b = b(:,2);
        end
        
        cc = corrcoef(a,b);
        plot(a,b,'.');
        xlabel('gt iou');
        if oi == 1, ylabel({'mnr with prior density';'est P(iou > .5)'}); else, ylabel('est P(iou > .5)'); end
        legend(['cc: ' num2str(cc(1,2))],'location','southeast');
    end
    
%% take a look at decision variable distributions
    
    figure();
    
    num_methods = 7;
    
    % internal
    for oi = 1:num_situation_objects
        subplot2(num_methods,num_situation_objects,1,oi);
        obj_inds = eq(oi,box_source_obj_type);
        a = box_proposal_gt_IOUs(obj_inds);
        b = internal_support(obj_inds);
        histn( b, a >= .5, 50 );
        xlim([-.3,1.3]);
        title(p.situation_objects{oi});
    end
    
    % total prior
    for oi = 1:num_situation_objects
        subplot2(num_methods,num_situation_objects,2,oi);
        obj_inds = eq(oi,box_source_obj_type);

        a = box_proposal_gt_IOUs(obj_inds);
        internal = internal_support(obj_inds);
        external = external_support_function( box_density_prior( obj_inds ));
        b = total_support_func(internal, external, oi, b_prior);
        histn( b, a >= .5, 50 );
        xlim([-.3,1.3]);
    end
    
    % total conditioned 1a
    for oi = 1:num_situation_objects
        subplot2(num_methods,num_situation_objects,3,oi);
        obj_inds = eq(oi,box_source_obj_type);
        
        a = box_proposal_gt_IOUs(obj_inds);
        internal = internal_support(obj_inds);
        external = external_support_function( box_density_conditioned_1a( obj_inds ));
        b = total_support_func(internal, external, oi, b_conditioned_1a);
        histn( b, a >= .5, 50 );
        xlim([-.3,1.3]);
    end
    
    % total conditioned 1b
    for oi = 1:num_situation_objects
        subplot2(num_methods,num_situation_objects,4,oi);
        obj_inds = eq(oi,box_source_obj_type);
        
        a = box_proposal_gt_IOUs(obj_inds);
        internal = internal_support(obj_inds);
        external = external_support_function( box_density_conditioned_1b( obj_inds ));
        b = total_support_func(internal, external, oi, b_conditioned_1b);
        histn( b, a >= .5, 50 );
        xlim([-.3,1.3]);
    end
    
    % total conditioned 2
    for oi = 1:num_situation_objects
        subplot2(num_methods,num_situation_objects,5,oi);
        obj_inds = eq(oi,box_source_obj_type);
        
        a = box_proposal_gt_IOUs(obj_inds);
        internal = internal_support(obj_inds);
        external = external_support_function( box_density_conditioned_2( obj_inds ));
        b = total_support_func(internal, external, oi, b_conditioned_2);
        histn( b, a >= .5, 50 );
        xlim([-.3,1.3]);
    end
    
    % mnr prior
    for oi = 1:num_situation_objects
        subplot2(num_methods,num_situation_objects,6,oi);
        obj_inds = eq(oi,box_source_obj_type);
        
        a = box_proposal_gt_IOUs(obj_inds);
        internal = internal_support(obj_inds);
        external = external_support_function( box_density_prior( obj_inds ));
        
        if use_mixing
            b = mnrval(b_mnr_prior(oi,:)', [internal, external, internal.*external] );
            b = b(:,2);
        else
            b = mnrval(b_mnr_prior(oi,:)', [internal, external] );
            b = b(:,2);
        end
        histn( b, a >= .5, 50 );
        xlim([-.3,1.3]);
    end
    
    % mnr conditioned 2
    for oi = 1:num_situation_objects
        subplot2(num_methods,num_situation_objects,7,oi);
        obj_inds = eq(oi,box_source_obj_type);
        
        a = box_proposal_gt_IOUs(obj_inds);
        internal = internal_support(obj_inds);
        external = external_support_function( box_density_prior( obj_inds ));
        
        if use_mixing
            b = mnrval(b_mnr_conditioned_2(oi,:)', [internal, external, internal.*external] );
            b = b(:,2);
        else
            b = mnrval(b_mnr_conditioned_2(oi,:)', [internal, external] );
            b = b(:,2);
        end
        histn( b, a >= .5, 50 );
        xlim([-.3,1.3]);
    end
    
    
%%  leash activation for high gt boxes

    cuts = [0 .15 .35 .65 .8 .9 inf];
    figure;
    inds_leash = eq( box_source_obj_type, 3);
     
    for ci = 1:length(cuts)-1
        subplot(1,length(cuts)-1,ci);
        inds_gt_range = gt( box_proposal_gt_IOUs, cuts(ci) ) & lt( box_proposal_gt_IOUs, cuts(ci+1) );
        cur_inds = inds_leash & inds_gt_range;
        hist( internal_support(cur_inds), 50 );
        title(['gt range: ' num2str(cuts(ci)) ' to ' num2str(cuts(ci+1))]);
        xlabel('estimated IOU');
    end
    
    cuts = [0 .15 .35 .65 .8 .9 inf];
    figure;
    inds_leash = eq( box_source_obj_type, 3);
    
    for ci = 1:length(cuts)-1
        subplot(1,length(cuts)-1,ci);
        inds_est_range = gt( internal_support, cuts(ci) ) & lt( internal_support, cuts(ci+1) );
        cur_inds = inds_leash & inds_est_range;
        hist( box_proposal_gt_IOUs(cur_inds), 50 );
        title(['est IOU range: ' num2str(cuts(ci)) ' to ' num2str(cuts(ci+1))]);
        xlabel('actual IOU');
    end
    
    % think about things in terms of probability that gt iou > x as a function of y
    
    
   
    
     
