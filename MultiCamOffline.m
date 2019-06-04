function MultiCamOffline
  A = load('CamData.mat'); % Load Calibraion Points
  Main = load('MainData.mat'); % Load Main Global Variables
  CamNum = Main.NumberOfCamerasInArray;
  XWidth = Main.ResolutionOfCameraWidth;
  YHeight = Main.ResolutionOfCameraHeight;
  
  Depth = 0;   % Default Depth Value

  FrmStart = 200;   % Specify start frame(time)
  FrmEnd = 225; % End frame(time)
   
  loopRunning = true; % Is the video playing?
  DepthChanged = true; % Did you just change the Depth? (changes to false after first frame)
  CloseLoop = false; % Have you pressed the close button?
  pauseall = false; % Is the video paused?
  FPSTOTAL = 0;
  z = FrmStart; % frame variable % Specify start frame(time)
  zt = 0; % frame counter (will only increase by 1 even if user jumps ahead 30 frames) 
          % needed for FPS and Pause Delay Jumper
          
  % Setting Image Size
  xdata=[1 XWidth];
  ydata=[1 YHeight];
          
  % Gamma Correction for our Imagine RIT Setup (Change 0.5 to 1 for the Lab)
  lut = uint8(((0:255)/255.0).^0.5 * 255);
  
  for i = 1:CamNum
      % Generate the Calibration data from a base set of points in realtion
      % to all other point (Current Base = 3)
      TFORM(i) = cp2tform(A.CamData(:,:,i),A.CamData(:,:,3),'affine');
  end
  
  tic; ImgArray = LoadImages(FrmStart, FrmEnd); toc; % Load Images

  %% ---------------------Create Figure----------------------%

  hFigure = figure('Position',[0 0 1040 720],...    % Create a figure window
                   'MenuBar','none','Renderer','OpenGL','Resize','off');
  
  MainAxes = axes('Parent', hFigure, 'Units', 'pixels',...   % Create the Axis to display images on
                  'Position', [1 1 960 720], 'Visible', 'off');
  Timeline = axes('Parent', hFigure, 'Units', 'pixels',...   % Create the Axis to display timeline
                  'Position', [1 1 1 4], 'Visible', 'off');
  rectangle('Parent', Timeline,'FaceColor',[1 1 0],...
                          'Position', [0 0 1 4]);   
              
  uicontrol('Style','pushbutton',...  % Create the Up button #2
            'Position',[962 370 80 60],'String','^ Furth10 ^',...
            'HorizontalAlignment','center','Callback',@up_button10);                    
  uicontrol('Style','pushbutton',...  % Create the Up button
            'Position',[962 310 80 60],'String','^ Further ^',...
            'HorizontalAlignment','center','Callback',@up_button);      
  depthtext = uicontrol('Style','text','String','1','Position',[978 270 50 20],... % Depth Display
                        'HorizontalAlignment','center','FontSize',15);
  uicontrol('Style','pushbutton',...  % Create the Down button
            'Position',[962 190 80 60],'String','v Closer v',...
            'HorizontalAlignment','center','Callback',@down_button);
  uicontrol('Style','pushbutton',...  % Create the Down button #2
            'Position',[962 130 80 60],'String','v Clos10 v',...
            'HorizontalAlignment','center','Callback',@down_button10);         
  
  uicontrol('Style','text','String','FPS','Position',[972 105 60 20],... % FPS Static Text
                    'HorizontalAlignment','Left','FontSize',15);
  text2 = uicontrol('Style','text','String','FPS','Position',[972 85 60 20],... % FPS Display
                    'HorizontalAlignment','Left','FontSize',15);
  uicontrol('Style','text','String','AVERAGE','Position',[972 65 60 13],... % Average Static Text
                    'HorizontalAlignment','Left','FontSize',10);
  text3 = uicontrol('Style','text','String','AVERAGE','Position',[972 45 60 20],... % FPS AVE Display
                    'HorizontalAlignment','Left','FontSize',15);
                
  PausePlay = uicontrol('Style','pushbutton',...  % Create the Pause/Play Button
                        'Position',[962 0 40 40],'String','PAUSE','FontSize',8,...
                        'HorizontalAlignment','center','Callback',@pause_play_button);
  StopButton = uicontrol('Style','pushbutton',...  % Create the Stop Button
                         'Position',[1002 0 40 40],'String','STOP','FontSize',8,...
                         'HorizontalAlignment','center','Callback',@stop_button);
  set(depthtext, 'String', num2str(Depth));   % Update the Default Text Value
  
  %% ------------------------------------------------------%
  %------------------------Start SAP-----------------------%
  %--------------------------------------------------------%
  
  while loopRunning == true  
    fpsStart = tic; % Start Frame Timer
    
    set(Timeline, 'Position', [1 1 (960/(FrmEnd-FrmStart+1))*(z-FrmStart+1) 4]);

    % Preallocate the memory for your image canvas (needs to be preallocated
    % everytime in order to clear the matrix for the next frame)
    AllPics = zeros(YHeight,XWidth,'uint16');
    if DepthChanged == true
      % Will Empty the "brightness" array when depth is changed
      AllPics2 = zeros(YHeight,XWidth,'uint16');
    end
    
    %% ---------------------Render 1 Depth--------------------------%
    %--------------------Transform And Add Images-------------------%
    for i = 1:CamNum
      %% Transform each camera's frame
      % M:Affine Transform Matrix, Adjust each camera based on center camera
      CamShift = [0 0 0; 0 0 0; (((CamNum+1)/2)-i)*Depth 0 0];
      CalibMatrix = getfield(getfield(TFORM(i), 'tdata'), 'T'); % get the tansform matrix from 'cp2tform' calibration
      ABC = CalibMatrix + CamShift; % Add the camera shift and the calibration together
      R = maketform('affine', ABC); % tells the software that this is an affine transformation
      W = imtransform(ImgArray(:,:,:,i,z), R, 'nearest', 'XData', xdata, 'YData', ydata);   % Transforming each image (W = output)
      
      if DepthChanged == true % If you've changed the depth, move the brightness corrector array too
        % Figures out how many images overlap at what points and creates
        % numbers to divide by
        G = imtransform(ones(YHeight,XWidth,'uint8'), R, 'nearest', 'XData', xdata, 'YData', ydata);
        AllPics2 = AllPics2 + uint16(G); % Add each new camera
      end
     
      AllPics = AllPics + uint16(W);   % Add each camera image together to create one frame at one depth
    end
    DepthChanged = false;
    % Show the final image, reconverted to 8bits,corrected for gamma, and
    % divded correctly for brightness ("./" = divide two images)
    imshow(lut(uint8(AllPics./AllPics2 + 1)) ,'Parent',MainAxes);
    %% ---------------------------------------------------------------%
    
    if CloseLoop == true
      break
    end
    
    fpsEnd = toc(fpsStart); % Ends frame timer and converts it to Frames per Second
    
    pause(0.001); % Need a 1 millisecond delay or the 'while' loop will complete before displaying any frames
   
    if pauseall == false
      z = z + 1; % increases the frame
      zt = zt + 1; % increase the frame counter
      FPS = 1/fpsEnd; % Calculates the FPS 
      FPSTOTAL = FPSTOTAL + (FPS); % Add each FPS together to get a total
      set(text2, 'String', num2str(FPS)); % Updates FPS Display
      set(text3, 'String', num2str(FPSTOTAL/(zt))); % Updates FPS Average Display
    end
    
    if mod(zt,200) == 0  %divides by 200, looks for remainder of 0
      z = z + 1; % Jumps one extra frame every 200 frames to make up for the 1 millisecond 'pause' 
    end
    
    if z == FrmEnd+1
      loopRunning = false; % Ends the loop on if last frame has played
    end  
  end 
  %% ^^ Program End ^^ %%
  
  if loopRunning == false % Displays only if user didn't end it early
    disp('Done');
    %set(PausePlay, 'String', 'REPLAY');
    set(StopButton, 'String', 'CLOSE');
  end
    
  %% Button Callback Functions (aka Event Listeners)
  
  %----------- Up Buttons ------------%
  function up_button(hObject,eventData)
    Depth = Depth - 1;   % Subtracts 1 to Depth Value
    DepthChanged = true;
    set(depthtext, 'String', num2str(Depth)); % Update the Default Text Value
  end
  function up_button10(hObject,eventData) 
    Depth = Depth - 10;   % Subtracts 10 to Depth Value
    DepthChanged = true;
    set(depthtext, 'String', num2str(Depth));
  end

  %----------- Down Buttons ------------%
  function down_button(hObject,eventData)
    Depth = Depth + 1;   % Adds 1 to Depth Value
    DepthChanged = true;
    set(depthtext, 'String', num2str(Depth));
  end
  function down_button10(hObject,eventData)  
    Depth = Depth + 10;   % Adds 10 to Depth Value
    DepthChanged = true;
    set(depthtext, 'String', num2str(Depth));
  end
  
  %----------- Pause/Stop Buttons ------------%
  function pause_play_button(hObject,eventData) 
    if pauseall == false && loopRunning == true  
      pauseall = true; % Pauses 'While Loop'(z)
      set(PausePlay, 'String', 'PLAY');
    elseif pauseall == true && loopRunning == true
      pauseall = false; % Plays 'While Loop'(z)
      set(PausePlay, 'String', 'PAUSE');
    %elseif loopRunning == false % Replay Function
      %z = FrmStart; 
      %DepthChanged = true; 
      %CloseLoop = false;
      %pauseall = false; 
      %FPSTOTAL = 0;
      %zt = 0; 
      %loopRunning = true;
    end
  end
  function stop_button(hObject,eventData)
    CloseLoop = true; % Kills Loop
    disp('Closed');
    close all % Closes Figure
    clear all % Clears the Workspace Variables etc...
    return % Kills Main Function
  end
  
end