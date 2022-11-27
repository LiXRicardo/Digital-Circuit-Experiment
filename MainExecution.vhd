library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
USE ieee.numeric_std.all;

entity MainExecution is 
port(		
			  clk :  in std_logic;--1MHz
		  clk1kHz :  in std_logic;--1kHz
		MasterKey :  in std_logic;--总开关
		 StartKey :  in std_logic;--开始键
		 PauseKey :  in std_logic;--暂停键
		 ResetKey :  in std_logic;--复位键
		 
		   Time10 :  in std_logic_vector(3 downto 0);--加热时间十位
			Time1 :  in std_logic_vector(3 downto 0);--加热时间个位
		FireValue :  in std_logic_vector(1 downto 0);--火力值
		
   Matrix_Display : out std_logic;
		 --buzzer : out std_logic;--蜂鸣器
		
  Start_Animation : out std_logic;
Parameter_Setting : out std_logic;
	  Matrix_Fire : out std_logic_vector(1 downto 0);
   
	  SMG_Display : out std_logic;
 Finish_Animation : out std_logic;
 
	  Time10_DISP : out std_logic_vector(3 downto 0);--加热时间十位
	   Time1_DISP : out std_logic_vector(3 downto 0)--加热时间个位
	
);

end entity;

architecture transition of MainExecution is

type state_type is (s0,s1,s2,s3);
signal present_state,next_state : state_type;

signal clk1Hz : std_logic;

signal countdown10 : integer range 0 to 9;
signal  countdown1 : integer range 0 to 9;
signal FireValueTemp : std_logic_vector(1 downto 0);

signal FinishTemp : std_logic;

signal clk1Hz_divide_temp: std_logic;
signal clk1Hz_divide_counter: integer range 0 to 499;


begin
Clk_Divide_1Hz:process(clk1kHz)
begin
	if(clk1kHz'event and clk1kHz='1')then
		if(clk1Hz_divide_counter=499)then 
			clk1Hz_divide_temp<=not clk1Hz_divide_temp;
			clk1Hz_divide_counter<=0;
		else
			clk1Hz_divide_counter<=clk1Hz_divide_counter+1;
		end if;
	end if;
end process Clk_Divide_1Hz;
clk1Hz<=clk1Hz_divide_temp;

--SubState Logic
process(clk1kHz,present_state,MasterKey,StartKey,PauseKey,ResetKey)
begin
	case present_state is
	
		when s0 =>--Shutdown state
			if(MasterKey='1')then
				next_state<=s1;
			else
				next_state<=s0;
			end if;
			
		when s1 =>--Position in readiness
			if(MasterKey='0') then
				next_state<=s0;
			elsif(StartKey='1')then--StartKey'event and 
				next_state<=s2;
			elsif(PauseKey='1')then
				next_state<=s2;
			else
				next_state<=s1;
			end if;

		when s2=>--Heating state
			if(MasterKey='0') then
				next_state<=s0;
			elsif(ResetKey='1') then
				next_state<=s1;
			elsif(countdown10=0 and countdown1=0)then --Finsh the heating 
				next_state<=s1;
			elsif(PauseKey='1') then
				next_state<=s1;
			else
				next_state<=s2;
			end if;

		when s3=>--Reserved state
			null;--next_state<=s0;
			
		when others=>null;
	end case;
end process;

--State Register
process(clk1kHz)
begin
	if(clk1kHz'event and clk1kHz='1') then
		present_state<=next_state;
	end if;
end process;

--Output Logic
process(clk1kHz,present_state)
begin
	case present_state is 
		when s0 =>Start_Animation<='1';Parameter_Setting<='0';SMG_Display<='0';Matrix_Display<='0';--Finish_Animation<='0';--关机状态
		when s1 =>Start_Animation<='0';Parameter_Setting<='1';SMG_Display<='1';Matrix_Display<='0';--Finish_Animation<='0';--待机状态
		when s2 =>Start_Animation<='0';Parameter_Setting<='0';SMG_Display<='1';Matrix_Display<='1';--Finish_Animation<='1';--加热状态
		when s3 =>null;--预留暂停状态
		when others=>null;
	end case;
end process;

----用于在参数设置时(S1待机状态下)传递时间、火力等参数
--Parameter_Transmit:process(clk)
--begin
--	if(clk'event and clk='1')then 
--		if(present_state=s1)then
--			countdown10 <= to_integer(unsigned(Time10));
--			countdown1 <= to_integer(unsigned(Time1));
--			FireValueTemp <= FireValue;
--		end if;
--		
--	end if;
--end process Parameter_Transmit;
--
----加热时间倒计时(S2 Heating State)
--countdown:process(clk1Hz)
--begin
--if(present_state=s2) then
--	if(clk1Hz'event and clk1Hz='1')then
--		if countdown1=0 and countdown10>0 then
--			countdown10<=countdown10-1;
--			countdown1<=9;
--		elsif countdown1>0 then
--			countdown1<=countdown1-1;
--		end if;
--	end if;
--end if;
--end process countdown;

--用于在参数设置时(S1待机状态下)传递时间、火力等参数
--和加热时间倒计时(S2 Heating State)
Parameter_Transmit_and_countdown:process(clk1Hz)
begin
	if(clk1Hz'event and clk1Hz='1')then
		if(present_state=s0)then
			Matrix_Fire <="00";
			countdown10 <= 0;
			countdown1 <= 0;
		end if;
		
		if(present_state=s1)then
			countdown10 <= to_integer(unsigned(Time10));
			countdown1 <= to_integer(unsigned(Time1));
			FireValueTemp <= FireValue;
			Matrix_Fire <="00";
		end if;
		
		if(present_state=s2) then
			--Matrix_Fire <= FireValueTemp;
			if(clk1Hz'event and clk1Hz='1')then
				if countdown1>0 then
					countdown1<=countdown1-1;
				elsif countdown1=0 and countdown10>0 then
					countdown10<=countdown10-1;
					countdown1<=9;
				end if;
			end if;
		end if;	
	end if;
	
	Time10_DISP<=std_logic_vector(to_signed(countdown10, Time10_DISP'length));
	Time1_DISP<=std_logic_vector(to_signed(countdown1, Time1_DISP'length));
	Matrix_Fire <= FireValueTemp;
	
end process Parameter_Transmit_and_countdown;


--加热结束后的操作
finish:process(next_state,clk)
begin

	if((present_state=s2 and countdown1=0 and countdown10=0) or (present_state=s1 and countdown1=0 and countdown10=0))then-- and next_state=s1 and 
		Finish_Animation<='1';
	else
		Finish_Animation<='0';
	end if;

--	if(present_state=s2 and next_state=s1)then
--		Finish_Animation<='0';
--	end if;

end process finish;



--heating:process(clk1)
--Process(clk,Start_Animation)
--begin
--	if(clk='0')then
--		--if(Start_Animation='1' and Start_Animation'LAST_VALUE='0')
--		if(Start_Animation'event and Start_Animation='1') then
--			Start_Animation_Temp<=1;
--		end if;
--	end if;
--end process;


end architecture;