using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace pcHealthPlus_VS
{
    public partial class toolForm : Form
    {
        public toolForm()
        {
            InitializeComponent();
        }

        private void toolForm_Load(object sender, EventArgs e)
        {

        }
        // Start of code/interface
        
        // navbar menu
        private void toolsMenuSubForm(object sender, ToolStripItemClickedEventArgs e)
        {

        }

        // Time of day

        private void timeLabel2_Timer(object sender, EventArgs e)
        {
            labelTimer2.Start();
            timeLabel2.Text = DateTime.Now.ToString("HH:mm");
        }

        private void timeLabel2_Load(object sender, EventArgs e)
        {
            timeLabel2.Text = DateTime.Now.ToString("HH:mm");
            labelTimer2.Start();
        }

        // Menu functions

        private void menuToolStripMenuItem2_Click(object sender, EventArgs e)
        {

        }

        private void mainToolStripMenuItem_Click(object sender, EventArgs e)
        {
            var Forms1 = new Form1();
            Forms1.Show();
        }

        private void programsToolStripMenuItem_Click(object sender, EventArgs e)
        {
            var Forms3 = new programForm();
            Forms3.Show();
        }

        private void gitHubToolStripMenuItem_Click(object sender, EventArgs e)
        {
            System.Diagnostics.Process.Start("https://github.com/REALSDEALS/pcHealthPlus-VS");
        }

        private void helpMenuButton_Click(object sender, EventArgs e)
        {
            var Forms4 = new copyrightForm();
            Forms4.Show();
        }

        // Closes the application 'tool' window.
        private void quitToolStripMenuItem_Click(object sender, EventArgs e)
        {
            this.Close();
        }
    }
}
