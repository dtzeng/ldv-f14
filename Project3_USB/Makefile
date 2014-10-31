CC=vcs

FLAGS=-sverilog -debug -assert filter -assert enable_diag

default: full

student: top.sv utils/usbBusAnalyzer.svp tb.sv usbHost.sv utils/thumb.sv.e 
	$(CC) $(FLAGS) top.sv utils/usbBusAnalyzer.svp tb.sv usbHost.sv utils/thumb.sv.e

simple: top.sv utils/usbBusAnalyzer.svp utils/TA_tb_simple.svp usbHost.sv utils/thumb.sv.e
	$(CC) $(FLAGS) top.sv utils/usbBusAnalyzer.svp utils/TA_tb_simple.svp usbHost.sv utils/thumb.sv.e

full: top.sv utils/usbBusAnalyzer.svp utils/TA_tb_full.svp usbHost.sv utils/thumb.sv.e
	$(CC) $(FLAGS) top.sv utils/usbBusAnalyzer.svp utils/TA_tb_full.svp usbHost.sv utils/thumb.sv.e

faulty: top.sv utils/usbBusAnalyzer.svp utils/TA_tb_faults.svp usbHost.sv utils/thumb_faulty.sv.e
	$(CC) $(FLAGS) top.sv utils/usbBusAnalyzer.svp utils/TA_tb_faults.svp usbHost.sv utils/thumb_faulty.sv.e

prelab: top.sv utils/usbBusAnalyzer.svp utils/prelab_tb.svp usbHost.sv utils/prelab_thumb.sv.e
	$(CC) $(FLAGS) top.sv utils/usbBusAnalyzer.svp utils/prelab_tb.svp usbHost.sv utils/prelab_thumb.sv.e

clean:
	rm -rf simv
	rm -rf simv.daidir
	rm -rf csrc
	rm -rf ucli.key
	rm -rf simv.vdb
	rm -rf DVEfiles
	rm -rf inter.vpd
