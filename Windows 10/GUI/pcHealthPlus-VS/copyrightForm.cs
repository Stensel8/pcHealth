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
    public partial class copyrightForm : Form
    {
        public copyrightForm()
        {
            InitializeComponent();
        }

        private void pictureBox1_Click(object sender, EventArgs e)
        {

        }

        private void copyrightForm_Load(object sender, EventArgs e)
        {

        }
        // This label is invisible; small error on my side...
        private void learnMoreLabel_Click(object sender, EventArgs e)
        {
            
        }

        // Learn more link
        private void learnMoreLinkLabel_onClick(object sender, EventArgs e)
        {
            System.Diagnostics.Process.Start("https://github.com/REALSDEALS/pcHealthPlus-VS/wiki");
        }
    }
}
